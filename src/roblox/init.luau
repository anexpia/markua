--!nonstrict
--!optimize 2

local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local IsClient = RS:IsClient()

local Markua = require(script.BaseMarkua)

type BaseFormatter = Markua.BaseFormatter

type TextFormatter = BaseFormatter & {
	TextLabel: TextLabel,
	read Text: string,
	
	read Contexts: {
		Input: boolean,
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

local TextFormatterInfo: {[TextLabel]: TextFormatter} = {}
local AutoUpdatingFormatters: {[TextFormatter]: boolean} = {}

local MarkuaRbx = {} 
for k, v in Markua do MarkuaRbx[k] = v end 

MarkuaRbx.AllFormatters = TextFormatterInfo
MarkuaRbx.AutoUpdatingFormatters = AutoUpdatingFormatters

-- Assigns a TextFormatter to the provided textlabel that processes tags everytime the textlabel's text is changed.
function MarkuaRbx.BindFormatter(textlabel: TextLabel): TextFormatter
	local old = TextFormatterInfo[textlabel]
	if old then return old end
	
	if not IsValidTextInstance(textlabel) then return end
	
	local formatter: TextFormatter = Markua.CreateFormatter() :: any
	formatter.CacheEnabled = true
	formatter.TextLabel = textlabel
	formatter.IsAutoUpdating = false 
	formatter.Connections = {}
	
	local originaltext = textlabel.Text
	
	local function UpdateText(isForceUpdate, overridetext: string?, isautoupdate: boolean?)
		local newtext = if isForceUpdate then originaltext else (overridetext or textlabel.Text)
		
		if not isForceUpdate then
			if newtext == formatter.Text then return end 
			if overridetext and newtext == originaltext then return end
			
			originaltext = newtext
		end
		
		-- when auto-updating, use cache and keep contexts unchanged.
		formatter.LastFormatIdx = 0
		formatter.UseCache = not not isautoupdate
		
		if not isautoupdate then
			formatter.ShouldAutoUpdate = false
			table.clear(formatter.Contexts)
		end
		
		newtext = Markua.FormatText(formatter, newtext)
		
		local shouldAutoUpdate = formatter.ShouldAutoUpdate
		if shouldAutoUpdate ~= formatter.IsAutoUpdating then
			AutoUpdatingFormatters[formatter] = if shouldAutoUpdate then true else nil :: any
			formatter.IsAutoUpdating = shouldAutoUpdate
		end
				
		if newtext ~= formatter.Text then
			formatter.Text = newtext
			textlabel.Text = newtext
		end
	end
	
	formatter.UpdateText = UpdateText
	TextFormatterInfo[textlabel] = formatter
	
	table.insert(formatter.Connections, textlabel:GetPropertyChangedSignal("Text"):Connect(UpdateText))
	
	UpdateText()
	
	return formatter
end

-- Removes the formatter associated with the provided textlabel.
function MarkuaRbx.UnbindFormatter(textlabel: TextLabel)
	local formatter = TextFormatterInfo[textlabel]
	if formatter then
		for _, v in formatter.Connections do 
			v:Disconnect()
		end
		
		if formatter.IsAutoUpdating then
			AutoUpdatingFormatters[formatter] = nil
		end
		
		textlabel.Text = formatter.Text
		
		table.clear(formatter)
		TextFormatterInfo[textlabel] = nil
	end
end

-- Updates the text for the provided textlabel.
-- If a formatter is associated with it. directly updates the text via it rather than firing the text changed signal.
function MarkuaRbx.SetText(textlabel: TextLabel, text: string)
	local formatter = TextFormatterInfo[textlabel]
	if formatter then
		formatter.UpdateText(nil, text)
	else 
		textlabel.Text = text
	end
end

local ListenersStarted = false

-- Starts listening for text objects tagged with "TextFormatted" and automatically adds/removes formatters for them
-- "tagOverride" parameter allows you to specify a different tag to listen for, if you don't want to use "TextFormatted".
function MarkuaRbx.StartListeners(tagOverride: string?)
	if ListenersStarted then return end
	ListenersStarted = true

	if IsClient then
		local tagname = tagOverride or "TextFormatted"

		CollectionService:GetInstanceAddedSignal(tagname):Connect(MarkuaRbx.BindFormatter)
		for _, textLabel in CollectionService:GetTagged(tagname) do
			MarkuaRbx.BindFormatter(textLabel)
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
