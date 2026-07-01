--!nonstrict
--!optimize 2

local Markua = {}

export type BaseFormatter = {
	read IsStatic: boolean,
	
	CacheEnabled: boolean?,
	UseCache: boolean?,
	
	LastFormatIdx: number,
	read FormatCache: {{
		text: string,
		toidx: number,
	}},
}

export type TagCallback = (formatter: BaseFormatter, attr: string, innerText: string?, processInner: (string) -> string) -> (string, boolean?)
export type FormatTag = {
	read callback: TagCallback,
	read closeTag: string?,
}

local FormatTags: {[string]: FormatTag} = {}

@native
local function ProcessTag(formatter: BaseFormatter, tag: string, attr: string, innerText: string?, processInner: (string) -> string)
	local idx = formatter.LastFormatIdx + 1
	formatter.LastFormatIdx = idx 
	
	if formatter.UseCache and formatter.CacheEnabled then
		-- check cache. this assumes we're reusing the exact same text as the one previously processed.
		
		local old = formatter.FormatCache[idx]
		if old then 
			formatter.LastFormatIdx = old.toidx
			return old.text
		end
	end
	
	local tagInfo = FormatTags[tag]
	local callback = tagInfo and tagInfo.callback
	
	local result: string
	local nocache: boolean?
	
	if callback then
		result, nocache = callback(formatter, attr, innerText, processInner)
	elseif innerText then
		result = `<{tag}{if attr ~= "" then ` {attr}` else ""}>{processInner(innerText)}</{tag}>`
	else
		result = `<{tag}{if attr ~= "" then ` {attr}` else ""} />`
	end
	
	if not (nocache or formatter.IsStatic) and formatter.CacheEnabled then
		local toidx = formatter.LastFormatIdx
	
		for i = idx + 1, toidx do 
			if not formatter.FormatCache[i] then
				-- a subtag has no caching, so cant cache here.
				formatter.FormatCache[idx] = nil
				return result
			end
		end
		
		formatter.FormatCache[idx] = {
			text = result,
			toidx = toidx, -- idx to jump to when reading cache result. because subtags exist
		}
	else 
		formatter.FormatCache[idx] = nil 
	end
	
	return result
end

-- Formats the provided string using the provided formatter object.
@native
function Markua.FormatText(formatter: BaseFormatter, text: string): string
	local function processInner(inner: string)
		return Markua.FormatText(formatter, inner)
	end
	
	local result = ""
	local i = 1
	
	local textlen = #text
	while i <= textlen do
		local startIdx, endIdx, tag, attr, lastchar = string.find(text, "<(%w+)%f[%W]%s*(.-)%s*(/?)>", i)
		if not startIdx then
			result ..= string.sub(text, i)
			break
		end
		
		local tagInfo = FormatTags[tag]
		local isVoidTag = lastchar == "/"
		
		if isVoidTag then
			if tagInfo and tagInfo.closeTag then
				result ..= string.sub(text, i, endIdx)
			else 
				local replacement = ProcessTag(formatter, tag, attr, nil, processInner)
				result ..= string.sub(text, i, startIdx - 1)
				result ..= replacement
			end
			
		elseif tagInfo and not tagInfo.closeTag then
			result ..= string.sub(text, i, endIdx)
		else
			local searchIdx = endIdx + 1
			local closeTag = if tagInfo then tagInfo.closeTag else (`</{tag}>`)
			
			local nextCloseStart, nextCloseEnd = string.find(text, closeTag, searchIdx, true)
			
			if nextCloseStart then
				local innerChunk = string.sub(text, searchIdx, nextCloseStart - 1)

				if string.find(innerChunk, `<{tag}%f[%W]`) then
					-- nesting of the same tag exists. life is bad. need to find actual closing tag.
					local depth = 1
					local tempSearchIdx = searchIdx

					local searchtag = `<{tag}%f[%W].-(/?)>`
					
					while true do
						nextCloseStart, nextCloseEnd = string.find(text, closeTag, tempSearchIdx, true)
						if not nextCloseStart then break end
						
						local chunk = string.sub(text, tempSearchIdx, nextCloseStart - 1)
						local nextOpenStart, nextOpenEnd, lastchar = string.find(chunk, searchtag)
						
						if nextOpenStart then
							if lastchar ~= "/" then depth += 1 end
							tempSearchIdx += nextOpenEnd
						else
							depth -= 1
							if depth == 0 then break end
							
							tempSearchIdx = nextCloseEnd + 1
						end
					end
				end
			end
			
			if nextCloseStart then
				local innerText = string.sub(text, searchIdx, nextCloseStart - 1)
	
				local replacement = ProcessTag(formatter, tag, attr, innerText, processInner)
				result ..= string.sub(text, i, startIdx - 1)
				result ..= replacement
	
				i = nextCloseEnd + 1
				continue
			else
				result ..= string.sub(text, i, endIdx)
			end
		end
		
		i = endIdx + 1
	end
	
	return result
end

local StaticFormatter: BaseFormatter = {
	IsStatic = true,
	
	FormatCache = {},
	LastFormatIdx = 0,
	UseCache = false,
} :: any

-- Creates a new formatter object.
function Markua.CreateFormatter(): BaseFormatter
	return {
		IsStatic = false,
		
		UseCache = false,
		LastFormatIdx = 0,
		FormatCache = {},
	}
end

-- Registers a custom tag. Callback should return new text, and <strong>true</strong> if the text cant be cached.
-- If `isVoid` is true, the tag will be processed as a void tag, and innerText won't be provided to the callback.
-- Void tags are written as <strong><tag /></strong> instead of <strong><tag> text </tag></strong>.
function Markua.RegisterTag(tagName: string, isVoid: boolean?, callback: TagCallback)
	FormatTags[tagName] = {
		callback = callback, 
		closeTag = if isVoid then nil else `</{tagName}>`
	}
end

-- Removes a previously registered tag by its name.
function Markua.RemoveTag(tagName: string)
	FormatTags[tagName] = nil
end

-- Formats the provided string without the need for a formatter object.
function Markua.ProcessText(text: string): string
	StaticFormatter.LastFormatIdx = 0
	return Markua.FormatText(StaticFormatter, text)
end

-- Parses the provided value into a boolean, number, or string.
-- If the value is not a valid boolean or number, it will be returned as a string.
@native
local function parseAttributeValue(value: string): string | number | boolean
	if value == "true" then return true end
	if value == "false" then return false end
	
	local num = tonumber(value)
	if num then return num end
	
	-- return `Malformed attribute value: '{value}' is not a valid string, number, or boolean.`
	return value
end

Markua.ParseAttrValue = parseAttributeValue

-- Parses the provided attribute string into a dictionary.
-- Attribute format must be <strong>a:1234 b:"string with spaces" c:true</strong>
@native
function Markua.ParseAttrDict(attr: string): ({[string]: any}?, string?)
	local dict = {}
	local i = 1
	
	local attrlen = #attr
	while i <= attrlen do
		local _, keyEnd, key = string.find(attr, "([%w_]+):", i)
		
		if key then
			i = keyEnd + 1
			
			local nextCharIdx = string.find(attr, "^%s", i)
			if nextCharIdx then i = nextCharIdx end
			
			local valStart, valEnd, val
			local quote = string.sub(attr, i, i)
			
			if quote == '"' or quote == "'" then
				valStart, valEnd = string.find(attr, `^%b{quote}{quote}`, i)
				
				if valStart then val = string.sub(attr, valStart + 1, valEnd - 1)
				else return nil, `Malformed attribute: missing closing quote for key '{key}'` end
			else
				valStart, valEnd, val = string.find(attr, "^(%S+)", i)
				if valStart then val = parseAttributeValue(val)
				else return nil, `Malformed attribute: missing value for key '{key}'` end
			end
			
			dict[key] = val
			i = valEnd + 1
		else
			break -- no more valid keys.
		end
	end
	
	return dict
end

-- Parses the provided attribute string into an array. 
-- Attribute format must be <strong>1234 "string with spaces" true</strong>
@native
function Markua.ParseAttrArray(attr: string): ({any}?, string?)
	local arr = {}
	local arrcount = 0
	
	local i = 1
	
	local attrlen = #attr
	while i <= attrlen do
		local nextCharIdx = string.find(attr, "[^%s%c]", i)
		
		if not nextCharIdx then break end -- no more valid values.
		i = nextCharIdx
		
		local valStart, valEnd, val
		local quote = string.sub(attr, i, i)
		
		if quote == '"' or quote == "'" then
			valStart, valEnd = string.find(attr, `^%b{quote}{quote}`, i)
			
			if valStart then val = string.sub(attr, valStart + 1, valEnd - 1)
			else return nil, `Malformed array attribute: missing closing quote` end
		else
			valStart, valEnd, val = string.find(attr, "^([^%s%c]+)", i)
			
			if valStart then val = parseAttributeValue(val)
			else return nil, `Malformed array attribute: expected value` end
		end
		
		arrcount += 1
		arr[arrcount] = val
			
		i = valEnd + 1
	end
	
	return arr
end

return Markua
