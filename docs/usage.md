---
sidebar_position: 2
---

# Usage Guide

This covers core formatting capabilities of **Markua**.\
*Markua does not come with any tags predefined. You have to register them yourself.*

## Registering Tags

You can define custom tags using `Markua.RegisterTag`. Tag callbacks receive four arguments:
1. `formatter`: The current `Formatter` object.
2. `attr`: The raw attribute string provided inside the tag.
3. `innerText`: The content inside `<tag>...</tag>` (or `nil` for void tags).
4. `processInner`: A helper function to recursively format innerText.

### Standard Tag Example

```lua
local symbols = {"!", "@", "#", "$", "%", "^", "&", "*", "?", "~"}

Markua.RegisterTag("wackify", false, function(formatter, attr, innerText, processInner)
    local text = processInner(innerText)
    local result = ""
    
    -- randomly add symbols that replace characters or are added afterwards.
    for i = 1, #text do
        local char = string.sub(text, i, i)
        
        if math.random() < 0.3 then
            result ..= symbols[math.random(1, #symbols)]
        elseif math.random() < 0.3 then
            result ..= char .. symbols[math.random(1, #symbols)]
        else
            result ..= char
        end
    end
    
    -- return true as the second value to mark this as not cacheable. the result always changes.
    return result, true
end)

Markua.RegisterTag("uppercase", false, function(formatter, attr, innerText, processInner)
    return string.upper(processInner(innerText))
end)

print(Markua.ProcessText("<uppercase><wackify>What is happening to me</wackify></uppercase>"))
```

### Void Tag Example

If a tag has no inner content (written as `<tag />`), set `isVoid` to `true`:

```lua

Markua.RegisterTag("currentobjective", true, function(formatter, attr, innerText, processInner)
    return Objectives.GetCurrentObjective()
end)

local text = Markua.ProcessText("Your current objective is <currentobjective />")
```

## Basic Formatting

For situations where caching isn't needed, such as processing tags once or only updating when needed, use `Markua.ProcessText`.

```lua
local Markua = require(path.to.Markua)

local formatted = Markua.ProcessText("Hello <b>world</b>!")
print(formatted)
```

If you have tags that dynamically change value even if the text itself doesn't, it is best to couple the text with a custom formatter. This allows you to cache the result of static tags and only update dynamic tags when needed.

`Formatter.CacheEnabled` enables or disables the cache.\
`Formatter.UseCache` controls whether the cache is read while processing text.

You should either disable `Formatter.UseCache` or clear `Formatter.FormatCache` when the text is changed or needs to be fully updated.

```lua
local UIS = game:GetService("UserInputService")
local Markua = require(path.to.Markua)

-- assume we have a textlabel on screen and referenced by 'textlabel' variable

local attrToInput = {
    touch = Enum.PreferredInput.Touch,
    gamepad = Enum.PreferredInput.Gamepad,
    mouse = Enum.PreferredInput.KeyboardAndMouse,
}

Markua.RegisterTag("inputcontext", false, function(formatter, attr, innerText, processInner)
    local targetinput = attrToInput[attr]
    
    if not targetinput then
        return `Invalid input type {attr}`
    elseif UIS.PreferredInput == targetinput then
        return processInner(innerText)
    else
        return ""
    end
end)

Markua.RegisterTag("timesince", true, function(formatter, attr, _, processInner)
    local n = tonumber(attr)

    if n then return tostring((math.round((tick() - n) * 10) / 10)), true -- returning true to indicate this doesn't cache.
    else return `Invalid Time {attr}` end
end)

local formatter = Markua.CreateFormatter()
formatter.CacheEnabled = true
formatter.UseCache = true

local template = `It has been <timesince {tick()}/> since this started.\
<inputcontext mouse>This text only appears if mouse is preferred input.</inputcontext>\
<inputcontext touch>This text only appears if touch is preferred input.</inputcontext>\
<inputcontext gamepad>This text only appears if gamepad is preferred input.</inputcontext>`

UIS:GetPropertyChangedSignal("PreferredInput"):Connect(function()
    -- clear the cache, so that inputcontext tag is re-evaluated.
    table.clear(formatter.FormatCache)
end)

while task.wait() do 
    -- constantly update the displayed text, only <timesince /> will be getting updated unless preferredinput changes.
   textlabel.Text = Markua.FormatText(formatter, template)
end
```

The Roblox integration of Markua is a better example of how this is used.

## Parsing Attributes

Markua provides functions to decode attribute strings into dictionaries or arrays.\
Each returns a table or an error message if the attributes are malformed.

### Dictionaries (`ParseAttrDict`)

```lua
local dict, err = Markua.ParseAttrDict('speed=15 active=true name="Player"')

if dict then
    print(dict.speed) -- 15 (number)
    print(dict.active) -- true (boolean)
    print(dict.name) -- "Player" (string) without the quotes
else error(err) end 
```

### Arrays (`ParseAttrArray`)

```lua
local arr, err = Markua.ParseAttrArray('100 250 false "Hello World"')
if arr then
    print(arr[1], arr[2], arr[3], arr[4]) -- 100 (number), 250 (number), false (boolean), "Hello World" (string)
else error(err) end
```
