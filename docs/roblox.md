---
sidebar_position: 3
---

# Roblox Integration

Markua is extended with features to make it easier to use in Roblox.
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
Simply call `StartListeners` when your client initializes.

```lua
Markua.StartListeners() -- Listens for the "TextFormatted" tag by default
```

You can also specify a custom tag name:

```lua
Markua.StartListeners("MyCustomTag")
```

## Dynamic Contexts & Input Handling

If you have tags that change value dynamically depending on certain conditions (such as player team, preferred input, or keybinds), you can flag what you want your formatter to update on by adding a key to `formatter.Contexts` and iterating over the formatters with specific contexts when needed using `GetFormattersByContext`.

You can also mark formatters as auto-updating in tag callbacks by setting `formatter.ShouldAutoUpdate` to `true`.
