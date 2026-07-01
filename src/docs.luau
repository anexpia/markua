

--------------------------------------------------------------------------------
-- MARKUA
--------------------------------------------------------------------------------

--[=[
	@class Markua
]=]

--- @interface BaseFormatter
--- @within Markua
--- .IsStatic boolean -- Whether this formatter instance is static. Only true for formatter of ProcessText()
--- .CacheEnabled boolean? -- Whether format results should be stored in a cache
--- .UseCache boolean? -- Whether the cached format results should be reused

--- @type TagCallback (formatter: BaseFormatter, attr: string, innerText: string?, processInner: (string) -> string) -> (string, boolean?)
--- @within Markua
--- Called whenever the tag is processed inside a string. 
--- Should return replacement string and an optional boolean (`true` if the output cannot be cached).

--- @function CreateFormatter
--- @within Markua
--- @return BaseFormatter
--- Creates a new formatter object.

--- @function RegisterTag
--- @within Markua
--- @param tagName string -- The identifier of the tag (eg. `"color"` for `<color>`).
--- @param isVoid boolean? -- If `true`, the tag is processed as a void tag (`<tag />`), and `innerText` will not be passed to the callback.
--- @param callback TagCallback
--- Registers a custom tag. Callback should return new text, and <strong>true</strong> if the text cannot be cached.

--- @function RemoveTag
--- @within Markua
--- @param tagName string
--- Removes a previously registered tag by its name.

--- @function FormatText
--- @within Markua
--- @param formatter BaseFormatter
--- @param text string 
--- @return string
--- Formats the provided string using the provided formatter object.

--- @function ProcessText
--- @within Markua
--- @param text string 
--- @return string
--- Formats the provided string without the need for a formatter object.

--- @function ParseAttrValue
--- @within Markua
--- @param value string
--- @return string | number | boolean
--- Parses the provided value into a boolean, number, or string.
--- If the value is not a valid boolean or number, it will be returned as a string.

--- @function ParseAttrDict
--- @within Markua
--- @param attr string -- The raw attribute string formatted as key-value pairs (eg. `a:123 b:"hello"`).
--- @return {[string]: any}? -- A dictionary of parsed keys and values, or `nil` if syntax is malformed.
--- @return string? -- An error message if attribute parsing failed.
--- Parses the provided attribute string into a dictionary.

--- @function ParseAttrArray
--- @within Markua
--- @param attr string -- The raw attribute string formatted as space-separated values (eg. `123 "string with spaces" true`).
--- @return {any}? -- An array of parsed attribute values, or `nil` if syntax is malformed.
--- @return string? -- An error message if attribute parsing failed.
--- Parses the provided attribute string into an array.

--------------------------------------------------------------------------------
-- MARKUAROBLOX
--------------------------------------------------------------------------------

--[=[
	@class MarkuaRoblox
	Wrapper for Markua in Roblox. Provides extra handy features.
	This extends Markua and contains all its members. Only extended members are listed.
]=]

--- @type TextObject TextLabel | TextBox | TextButton
--- @within MarkuaRoblox

--- @interface TextFormatter
--- @within MarkuaRoblox
--- .TextObject TextObject -- Text object associated with the formatter.
--- .Text string -- Current text of the textobject.
--- .Contexts { Input: boolean, [string]: boolean } -- Active context flags for triggering updates when a condition is met. (eg. input changes result in updates) 
--- .ShouldAutoUpdate boolean? -- Whether the formatter should be marked as being autoupdated each frame. Only change in callbacks.
--- .IsAutoUpdating boolean? -- Whether the formatter is being auto-updated every frame. Do not manually change.
--- .Connections {[any]: RBXScriptConnection}
--- .UpdateText (forceupdate: boolean?, overridetext: string?, isautoupdate: boolean?) -> ()
--- This extends BaseFormatter and contains all its members.

--- @prop AllFormatters {[TextObject]: TextFormatter}
--- @within MarkuaRoblox
--- Dictionary mapping text objects to their associated formatter.

--- @prop AutoUpdatingFormatters {[TextFormatter]: boolean}
--- @within MarkuaRoblox
--- Dictionary containing all formatters marked as auto-updating.

--- @prop FormattersByContext {[string]: {[TextFormatter]: any, n: number}}
--- @within MarkuaRoblox
--- Dictionary mapping context keys to formatters & their values. 'n' is number of formatters.

--- @function BindFormatter
--- @within MarkuaRoblox
--- @param textobject TextObject
--- @return TextFormatter
--- Assigns a TextFormatter to the provided textobject that processes tags everytime the textobject's text is changed.

--- @function UnbindFormatter
--- @within MarkuaRoblox
--- @param textobject TextObject
--- Removes the formatter associated with the provided textobject.

--- @function SetText
--- @within MarkuaRoblox
--- @param textobject TextObject
--- @param text string
--- Updates the text for the provided textobject.
--- If a formatter is associated with it, directly updates the text via it rather than firing the text changed signal.

--- @function GetFormattersByContext
--- @within MarkuaRoblox
--- @param keys ...string
--- @return {[TextFormatter]: boolean}
--- Returns a dictionary of formatters associated with the provided context key(s).

--- @function StartListeners
--- @within MarkuaRoblox
--- @param tagOverride string? -- Optional override for the tag used in CollectionService to find the text objects to format.
--- Starts listening for text objects tagged with `tagOverride` or "TextFormatted" and automatically adds/removes formatters for them
