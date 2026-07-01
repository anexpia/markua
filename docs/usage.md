---
sidebar_position: 2
---

# Usage Guide

This covers core formatting capabilities of Markua.
*Markua does not come with any tags predefined. You have to register them yourself.*

## Basic Formatting

For situations where caching isn't needed, such as processing tags once or only updating when needed, use `Markua.ProcessText`.

```lua
local Markua = require(path.to.Markua)

local formatted = Markua.ProcessText("Hello <b>world</b>!")
print(formatted)
```

## Creating a Formatter

If you have tags that dynamically change value even if the text itself doesn't, it's best to couple said text with a formatter in order to cache the results of tags that do cache. 

```lua
local formatter = Markua.CreateFormatter()
formatter.CacheEnabled = true
formatter.UseCache = true

local now = tick()
Markua.FormatText(formatter, `It has been <timesince {now}/> seconds.`) -- autoupdating each frame, assuming 'timesince' is set-up properly. 

```

## Registering Custom Tags

You can define custom tags using `Markua.RegisterTag`. Tag callbacks receive four arguments:
1. `formatter`: The current `Formatter` object.
2. `attr`: The raw attribute string provided inside the tag.
3. `innerText`: The content inside `<tag>...</tag>` (or `nil` for void tags).
4. `processInner`: A helper function to recursively format innerText.

### Standard Tag Example

```lua
local symbols = {"!", "@", "#", "$", "%", "^", "&", "*", "?", "~"}

Markua.RegisterTag("wackify", false, function(formatter, attr, innerText, processInner)
    local text = processInner(innerText or "")
    local result = ""
    
    -- Randomly add symbols that replace characters or are added afterwards.
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
    
    -- Return true as the second value to mark this as not cacheable. The result always changes.
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
-- assuming that you have a module named 'Objectives'.

Markua.RegisterTag("currentobjective", true, function(formatter, attr, innerText, processInner)
    return Objectives.GetCurrentObjective()
end)

local text = Markua.ProcessText("Your current objective is <currentobjective />")
```

## Parsing Attributes

Markua provides functions to decode attribute strings into dictionaries or arrays.\
Each returns a table or an error message if the attributes are malformed.

### Dictionaries (`ParseAttrDict`)

```lua
local dict, err = Markua.ParseAttrDict('speed:15 active:true name:"Player"')

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
