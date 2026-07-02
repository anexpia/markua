--!nonstrict
--!optimize 2
--!native

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
type FormatTag = {
	read callback: TagCallback,
	read void: boolean,
	
	read closeTag: string?,
	read depthSearchTag1: string?,
	read depthSearchTag2: string?,
}

local FormatTags: {[string]: FormatTag} = {}

local function ProcessTag(formatter: BaseFormatter, tagInfo: FormatTag, attr: string, innerText: string?, processInner: (string) -> string)
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
		
	local result: string, nocache: boolean? = tagInfo.callback(formatter, attr, innerText, processInner)
	
	if not (nocache) and formatter.CacheEnabled then
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

local concatArray = table.create(128, "")
local concatIdx = 0
local activeFormatters = 0 -- need to keep count of how many formatters are running at the same time
-- so they dont all use the same segments of concatArray

-- Formats the provided string using the provided formatter object.
local function FormatText(formatter: BaseFormatter, text: string): string
	local function processInner(inner: string)
		return FormatText(formatter, inner)
	end
	
	activeFormatters += 1
	
	local startConcatIdx = concatIdx
	local i = 1
	
	local textlen = #text
	while i <= textlen do
		local startIdx, endIdx, tag, attr, lastchar = string.find(text, "<(%w+)%f[%W]%s*(.-)%s*(/?)>", i)
		if not startIdx then
			concatIdx += 1
			concatArray[concatIdx] = string.sub(text, i)
			break
		end
		
		local tagInfo = FormatTags[tag]
		local isVoid = lastchar == "/"
		
		-- if a tag's type is mismatched, ignore it.
		if tagInfo and isVoid ~= tagInfo.void then tagInfo = nil end
		
		-- return tag as-is. if not found or mismatched ⬆️⬆️
		if not tagInfo then
			concatIdx += 1
			concatArray[concatIdx] = string.sub(text, i, endIdx)
			i = endIdx + 1
			
			continue
		end 
		
		if isVoid then
			local replacement = ProcessTag(formatter, tagInfo, attr, nil, processInner)
			
			if startIdx > i then
				concatIdx += 1
				concatArray[concatIdx] = string.sub(text, i, startIdx - 1)
			end
			
			concatIdx += 1
			concatArray[concatIdx] = replacement
		else
			local searchIdx = endIdx + 1
			local closeTag = tagInfo.closeTag
			
			local nextCloseStart, nextCloseEnd = string.find(text, closeTag, searchIdx, true)
			
			if nextCloseStart then
				local innerChunk = string.sub(text, searchIdx, nextCloseStart - 1)
				
				if string.find(innerChunk, tagInfo.depthSearchTag1) then
					-- nesting of the same tag exists. life is bad. need to find actual closing tag.
					local depth = 1
					local tempSearchIdx = searchIdx
					
					local searchtag = tagInfo.depthSearchTag2
					
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
	
				local replacement = ProcessTag(formatter, tagInfo, attr, innerText, processInner)
				
				if startIdx > i then
					concatIdx += 1
					concatArray[concatIdx] = string.sub(text, i, startIdx - 1)
				end
				
				concatIdx += 1
				concatArray[concatIdx] = replacement
	
				i = nextCloseEnd + 1
				continue
			else
				concatIdx += 1
				concatArray[concatIdx] = string.sub(text, i, endIdx)
			end
		end
		
		i = endIdx + 1
	end
	
	activeFormatters -= 1
	
	local result = table.concat(concatArray, "", startConcatIdx + 1, concatIdx)
	concatIdx = if activeFormatters == 0 then 0 else startConcatIdx
	
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

-- Registers a custom tag. Callback should return new text, and <strong>true</strong> if the text cannot be cached.
-- If `isVoid` is true, the tag will be processed as a void tag, and innerText won't be provided to the callback.
-- Void tags are written as <strong><tag /></strong> instead of <strong><tag> text </tag></strong>.
function Markua.RegisterTag(tagName: string, isVoid: boolean?, callback: TagCallback)
	FormatTags[tagName] = {
		callback = callback, 
		void = not not isVoid,
		
		closeTag = if isVoid then nil else `</{tagName}>`,
		depthSearchTag1 = if isVoid then nil else `<{tagName}%f[%W]`,
		depthSearchTag2 = if isVoid then nil else `<{tagName}%f[%W].-(/?)>`,
	}
end

-- Removes a previously registered tag by its name.
function Markua.RemoveTag(tagName: string)
	FormatTags[tagName] = nil
end

-- Formats the provided string using the provided formatter object.
function Markua.FormatText(formatter: BaseFormatter, text: string): string
	formatter.LastFormatIdx = 0
	return FormatText(formatter, text)
end

-- Formats the provided string without the need for a formatter object.
function Markua.ProcessText(text: string): string
	StaticFormatter.LastFormatIdx = 0
	return FormatText(StaticFormatter, text)
end

-- Parses the provided value into a boolean, number, or string.
-- If the value is not a valid boolean or number, it will be returned as a string.
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
-- Attribute format must be <strong>a=1234 b="string with spaces" c=true</strong>
function Markua.ParseAttrDict(attr: string): ({[string]: any}?, string?)
	local dict = {}
	local i = 1
	
	local attrlen = #attr
	while i <= attrlen do
		local _, keyEnd, key = string.find(attr, "([%w_]+)%s*=", i)
		
		if key then
			i = keyEnd + 1
			
			local nextCharIdx = string.find(attr, "%S", i)
			if nextCharIdx then i = nextCharIdx end
			
			local valStart, valEnd, _, val
			local quote = string.sub(attr, i, i)
			
			if quote == '"' or quote == "'" then
				local quotepattern = `%b{quote}{quote}`
				valStart, valEnd = string.find(attr, quotepattern, i)
				val = if valEnd then string.sub(attr, valStart + 1, valEnd - 1) else nil 
				
				while val do 
					local escstart, escend = string.find(val, "\\+$")
				
					if escend and (escend - escstart) % 2 == 0 then 
						-- skip past this
						_, valEnd = string.find(attr, quotepattern, valEnd)
						val = if valEnd then string.sub(attr, valStart + 1, valEnd - 1) else nil
						continue
					end
					
					break
				end 
				
				if val then 
					val = string.gsub(val, `\\([\\{quote}])`, "%1")
				else 
					return nil, `Malformed attribute: missing closing quote for key '{key}'` 
				end
			else
				valStart, valEnd, val = string.find(attr, "(%S+)", i)
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
local resultArray = table.create(128)
function Markua.ParseAttrArray(attr: string): ({any}?, string?)
	local arrcount = 0
	local i = 1
	
	local attrlen = #attr
	while i <= attrlen do
		local nextCharIdx = string.find(attr, "%S", i)
		
		if not nextCharIdx then break end -- no more valid values.
		i = nextCharIdx
		
		local valStart, valEnd, val
		local quote = string.sub(attr, i, i)
		
		if quote == '"' or quote == "'" then
			local quotepattern = `%b{quote}{quote}`
			valStart, valEnd = string.find(attr, quotepattern, i)
			val = if valEnd then string.sub(attr, valStart + 1, valEnd - 1) else nil 
						
			while val do 
				local escstart, escend = string.find(val, "\\+$")
				
				if escend and (escend - escstart) % 2 == 0 then 
					-- skip past this
					_, valEnd = string.find(attr, quotepattern, valEnd)
					val = if valEnd then string.sub(attr, valStart + 1, valEnd - 1) else nil
					continue
				end
				
				break
			end 
			
			if val then 
				val = string.gsub(val, `\\([\\{quote}])`, "%1")
			else 
				return nil, `Malformed array attribute: missing closing quote` 
			end
		else
			valStart, valEnd, val = string.find(attr, "(%S+)", i)
			
			if valStart then val = parseAttributeValue(val)
			else return nil, `Malformed array attribute: expected value` end
		end
		
		arrcount += 1
		resultArray[arrcount] = val
			
		i = valEnd + 1
	end
	
	local result = {}
	table.move(resultArray, 1, arrcount, 1, result)
	return result
end

return Markua
