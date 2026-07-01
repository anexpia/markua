--!nonstrict
--!optimize 2

local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local IsClient = RS:IsClient()

local Markua = require(script.BaseMarkua)

type TextObject = TextLabel | TextBox | TextButton

type BaseFormatter = Markua.BaseFormatter

type TextFormatter = BaseFormatter & {
	TextObject: TextObject,
	read Text: string,
	
	read Contexts: {
		[string]: boolean,
	},
	
	ShouldAutoUpdate: boolean?,
	read IsAutoUpdating: boolean?,
	
	read Connections: {[any]: RBXScriptConnection},
	read UpdateText: (forceupdate: boolean?, overridetext: string?, isautoupdate: boolean?) -> nil,
}

local function IsValidTextInstance(ins: Instance)
	return (not ins:IsDescendantOf(StarterGui)) and (ins:IsA("TextLabel") or ins:IsA("TextBox") or ins:IsA("TextButton"))
end

local TextFormatterInfo: {[TextObject]: TextFormatter} = {}
local AutoUpdatingFormatters: {[TextFormatter]: boolean} = {}
local FormattersByContext: {[string]: {[TextFormatter]: any, n: number}} = {}

local MarkuaRbx = {} 
for k, v in Markua do MarkuaRbx[k] = v end 

MarkuaRbx.AllFormatters = TextFormatterInfo
MarkuaRbx.AutoUpdatingFormatters = AutoUpdatingFormatters
MarkuaRbx.FormattersByContext = FormattersByContext

-- Assigns a TextFormatter to the provided textobject that processes tags everytime the textobject's text is changed.
function MarkuaRbx.BindFormatter(textobject: TextObject): TextFormatter
	local old = TextFormatterInfo[textobject]
	if old then return old end
	
	if not IsValidTextInstance(textobject) then return end
	
	local formatter: TextFormatter = Markua.CreateFormatter() :: any
	formatter.CacheEnabled = true
	formatter.TextObject = textobject
	formatter.IsAutoUpdating = false 
	formatter.Connections = {}
	formatter.Contexts = {}
	
	local originaltext = textobject.Text
	
	local function UpdateText(isForceUpdate, overridetext: string?, isautoupdate: boolean?)
		local newtext = if isForceUpdate then originaltext else (overridetext or textobject.Text)
		
		if not isForceUpdate then
			if newtext == formatter.Text then return end 
			if overridetext and newtext == originaltext then return end
			
			originaltext = newtext
		end
		
		-- when auto-updating, use cache and keep contexts unchanged.
		formatter.UseCache = not not isautoupdate
		
		if not isautoupdate then
			formatter.ShouldAutoUpdate = false
			for key in formatter.Contexts do formatter.Contexts[key] = false end
		end
		
		newtext = Markua.FormatText(formatter, newtext)
		
		if not isautoupdate then
			for key, val in formatter.Contexts do
				if val then
					local dict = FormattersByContext[key]
					
					if dict then
						if not dict[formatter] then dict.n += 1 end
					else
						dict = {n = 1}
						FormattersByContext[key] = dict
					end
					
					dict[formatter] = val
				else
					formatter.Contexts[key] = nil
					
					local dict = FormattersByContext[key]
					if dict and dict[formatter] then
						dict[formatter] = nil
						dict.n -= 1
						
						if dict.n <= 0 then FormattersByContext[key] = nil end
					end
				end
			end
		end
		
		local shouldAutoUpdate = formatter.ShouldAutoUpdate
		if shouldAutoUpdate ~= formatter.IsAutoUpdating then
			AutoUpdatingFormatters[formatter] = if shouldAutoUpdate then true else nil :: any
			formatter.IsAutoUpdating = shouldAutoUpdate
		end
				
		if newtext ~= formatter.Text then
			formatter.Text = newtext
			textobject.Text = newtext
		end
	end
	
	formatter.UpdateText = UpdateText
	TextFormatterInfo[textobject] = formatter
	
	table.insert(formatter.Connections, textobject:GetPropertyChangedSignal("Text"):Connect(UpdateText))
	
	UpdateText()
	
	return formatter
end

-- Removes the formatter associated with the provided textobject.
function MarkuaRbx.UnbindFormatter(textobject: TextObject)
	local formatter = TextFormatterInfo[textobject]
	if formatter then
		for _, v in formatter.Connections do 
			v:Disconnect()
		end
		
		if formatter.IsAutoUpdating then
			AutoUpdatingFormatters[formatter] = nil
		end
		
		for key in formatter.Contexts do
			local dict = FormattersByContext[key]

			if dict and dict[formatter] then
				dict[formatter] = nil
				dict.n -= 1
				
				if dict.n <= 0 then FormattersByContext[key] = nil end
			end
		end
		
		textobject.Text = formatter.Text
		
		table.clear(formatter)
		TextFormatterInfo[textobject] = nil
	end
end

-- Updates the text for the provided textobject.
-- If a formatter is associated with it. directly updates the text via it rather than firing the text changed signal.
function MarkuaRbx.SetText(textobject: TextObject, text: string)
	local formatter = TextFormatterInfo[textobject]
	if formatter then
		formatter.UpdateText(nil, text)
	else 
		textobject.Text = text
	end
end

-- Returns a dictionary of formatters associated with the provided context key(s)
function MarkuaRbx.GetFormattersByContext(...: string): {[TextFormatter]: boolean}
	local result = {}
	
	for i = 1, select("#", ...) do 
		local key = select(i, ...)
		local dict = FormattersByContext[key]
		
		if dict then
			for formatter in dict do
				if formatter == "n" then continue end 
				result[formatter] = true
			end
		end
	end
	
	return result
end

MarkuaRbx.GetFormattersByContext = MarkuaRbx.GetFormattersByContext

local ListenersStarted = false

-- Starts listening for text objects tagged with "TextFormatted" and automatically adds/removes formatters for them
-- "tagOverride" parameter allows you to specify a different tag to listen for, if you don't want to use "TextFormatted".
function MarkuaRbx.StartListeners(tagOverride: string?)
	if ListenersStarted then return end
	ListenersStarted = true
	
	if IsClient then
		local tagname = tagOverride or "TextFormatted"
		
		CollectionService:GetInstanceAddedSignal(tagname):Connect(MarkuaRbx.BindFormatter)
		for _, textObject in CollectionService:GetTagged(tagname) do
			MarkuaRbx.BindFormatter(textObject)
		end
		
		CollectionService:GetInstanceRemovedSignal(tagname):Connect(MarkuaRbx.UnbindFormatter)
		
		UIS:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			for _, formatter in TextFormatterInfo do 
				if formatter.Contexts.Input then
					formatter.UpdateText(true)
				end
			end
		end)
		
		RS.PreRender:Connect(function(dt)
			for formatter in AutoUpdatingFormatters do 
				formatter.UpdateText(true, nil, true)
			end
		end)
	end
end

return MarkuaRbx :: typeof(MarkuaRbx) & typeof(Markua)
