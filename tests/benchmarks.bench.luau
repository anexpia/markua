--!nonstrict
--!optimize 2

--[[
This file is for use by Benchmarker (https://boatbomber.itch.io/benchmarker)

|WARNING| THIS RUNS IN YOUR REAL ENVIRONMENT. |WARNING|
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Markua = require(ReplicatedStorage.Markua:Clone())

local sampleText = '<color val="#ff0000"><bold>Hello World!</bold></color> Hello<bold>Everyone</bold>! <icon id="12345678" />'
local hugeText = string.rep(sampleText .. " ", 100)
local attrDictStr = 'val="#ff0000" size=24 bold=true opacity=0.85 title="Hello World"'
local attrArrayStr = '"first value" true 100.5 false "second value"'

local uncachedFormatter
local cachedFormatter

local reps = 200

return {
	ParameterGenerator = function()
		return sampleText, attrDictStr, attrArrayStr, hugeText
	end,
	
	BeforeAll = function()
		Markua.RegisterTag("color", false, function(formatter, attr, innerText, processInner)
			return `<font color="{attr}">{processInner(innerText)}</font>`
		end)
		
		Markua.RegisterTag("bold", false, function(formatter, attr, innerText, processInner)
			return `<b>{processInner(innerText)}</b>`
		end)
		
		Markua.RegisterTag("icon", true, function(formatter, attr)
			return `rbxassetid://{attr}`
		end)
		
		uncachedFormatter = Markua.CreateFormatter()
		uncachedFormatter.CacheEnabled = false
		
		cachedFormatter = Markua.CreateFormatter()
		cachedFormatter.CacheEnabled = true
		cachedFormatter.UseCache = true
		-- Prime the cache once
		Markua.FormatText(cachedFormatter, sampleText)
		Markua.FormatText(cachedFormatter, hugeText)
	end,
	
	AfterAll = function()
		Markua.RemoveTag("color")
		Markua.RemoveTag("bold")
		Markua.RemoveTag("icon")
	end,
	
	Functions = {
		["ParseAttrDict"] = function(Profiler, text, dictStr, arrayStr, hugeText)
			for i = 1, reps do 
				Markua.ParseAttrDict(dictStr)
			end
		end,
		
		["ParseAttrArray"] = function(Profiler, text, dictStr, arrayStr, hugeText)
			for i = 1, reps do 
				Markua.ParseAttrArray(arrayStr)
			end
		end,
		
		["FormatText"] = function(Profiler, text, dictStr, arrayStr, hugeText)
			for i = 1, reps do 
				Markua.FormatText(uncachedFormatter, text)
			end
		end,
		
		["FormatText (Cached)"] = function(Profiler, text, dictStr, arrayStr, hugeText)
			for i = 1, reps do 
				Markua.FormatText(cachedFormatter, text)
			end
		end,
		
		["FormatText Huge"] = function(Profiler, text, dictStr, arrayStr, hugeText)
			for i = 1, reps / 100 do 
				Markua.FormatText(uncachedFormatter, hugeText)
			end
		end,
		
		["FormatText Huge (Cached)"] = function(Profiler, text, dictStr, arrayStr, hugeText)
			for i = 1, reps / 100 do 
				Markua.FormatText(cachedFormatter, hugeText)
			end
		end,
	},
}
