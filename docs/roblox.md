---
sidebar_position: 3
---

# Roblox Integration

**Markua** is extended with features to make it easier to use in Roblox.\
*Markua does not come with any tags predefined. You have to register them yourself.*

## Binding TextLabels

To attach Markua formatting directly to a `TextLabel`, `TextBox`, or `TextButton`, use `BindFormatter`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Markua = require(ReplicatedStorage.Markua)

local LocalPlayer = game:GetService("Players").LocalPlayer

local textLabel = script.Parent.TextLabel
local formatter = Markua.BindFormatter(textLabel)

textLabel.Text = `Welcome back, <pid {LocalPlayer.UserId}/>!` -- "Welcome back, <font color="#b74cff">anexpia</font>!"
```

To unbind and restore the original text:

```lua
Markua.UnbindFormatter(textLabel)
```

## Setting Text Directly

If you want to update text directly through an existing formatter without setting `TextLabel.Text`:

```lua
Markua.SetText(textLabel, "<fancytext>Hello World!</fancytext>") -- I don't feel like writing an example of how this would look, but you can imagine.
```

This is faster because text will only have to be changed once, particularly when you are changing it each frame.

## Automatic Listeners

Markua can automatically manage formatting text objects tagged with `TextFormatted` or whichever other tag you provide.
Simply call `StartListeners` when the client initializes.

```lua
Markua.StartListeners()
```

You can also specify a custom tag name:

```lua
Markua.StartListeners("MyCustomTag")
```

## Dynamic Contexts & Auto-updating

If you have tags that change value dynamically depending on certain conditions (such as player team, preferred input, or keybinds), you can flag what you want your formatter to update on by adding a key to `formatter.Contexts` and iterating over the formatters with specific contexts when needed using `GetFormattersByContext`.

You can also mark formatters as auto-updating in tag callbacks by setting `formatter.ShouldAutoUpdate` to `true`.

### Keybinds Example

If you have a tag that depends on the player's keybinds, You can add the keybind to the contexts and update every formatter with the keybind when it changes.

```lua
local Markua = require(path.to.Markua)
local ControlsModule = require(path.to.your.controls.module)

-- register a tag that displays the keybind for a certain action
Markua.RegisterTag("kb", true, function(formatter, attr)
    local display = ControlsModule.GetDisplay(attr)

    if display then
        formatter.Contexts[`kb{attr}`] = true
        return display
    else 
        return `Invalid Control {attr}`
    end
end)

-- update each formatter that has the keybind when the keybind changes
ControlsModule.ControlsChanged:Connect(function(controlname: string)
    local formatters = Markua.GetFormattersByContext(`kb{controlname}`)

    for formatter in formatters do
        formatter.UpdateText(true)
    end
end)

### Auto-updating Example

```lua
local Markua = require(path.to.Markua)

Markua.RegisterTag("timeuntil", true, function(formatter, attr, _, _)
    formatter.ShouldAutoUpdate = true -- marking this formatter as autoupdating.

    local start = tonumber(attr)
    if start then 
        return tostring(math.round((workspace:GetServerTimeNow() - start) * 10) / 10), true -- returning true to indicate this doesn't cache.
    else 
        return `Invalid Time {attr}`
    end
end)
```
