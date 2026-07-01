--!nonstrict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local Markua = require(ReplicatedStorage.Markua)

LogService:Info("Starting tests.")

local passed = 0
local failed = 0

local function test(name: string, func: () -> ())
	local success, err = pcall(func :: any)
	
	if success then
		passed += 1
		print(`[PASS] {name}`)
	else
		failed += 1
		warn(`[FAIL] {name}: {err}`)
	end
end

local function assertEqual(actual: any, expected: any, msg: string?, msgoverride: boolean?)
	if actual ~= expected then
		error(if msgoverride then msg else `{msg or"Mismatch"}: expected {expected}, but got {actual}.`)
	end
end

test("ParseAttrDict - simple", function()
	local dict, err = Markua.ParseAttrDict('color:"red" bold:true size:18 count:100.5')
	assertEqual(err, nil, "Should not return error", true)
	assert(dict ~= nil, "Dict should not be nil", true)
	
	assertEqual(dict.color, "red")
	assertEqual(dict.bold, true)
	assertEqual(dict.size, 18)
	assertEqual(dict.count, 100.5)
end)

test("ParseAttrDict - spaces in strings", function()
	local dict, err = Markua.ParseAttrDict('title:"Hello\tWorld" active:false')
	assertEqual(err, nil, "Should not return error", true)
	assert(dict ~= nil, "Dict should not be nil", true)
	
	assertEqual(dict.title, "Hello\tWorld")
	assertEqual(dict.active, false)
end)

test("ParseAttrDict - unquoted string", function()
	local dict, err = Markua.ParseAttrDict('color:red')
	assertEqual(err, nil, "Should not return error", true)
	assert(dict ~= nil, "Dict should not be nil", true)
	
	assertEqual(dict.color, "red")
end)

test("ParseAttrDict - malformed quoted string", function()
	local dict, err = Markua.ParseAttrDict('color:"red')
	assert(dict == nil, "Dict should be nil")
	assert(type(err) == "string", "Error message should exist")
end)

test("ParseAttrArray - simple", function()
	local arr, err = Markua.ParseAttrArray('"first string" true 76 false')
	assertEqual(err, nil, "Should not return error", true)
	assert(arr ~= nil, "Array should not be nil", true)
	
	assertEqual(#arr, 4, "Array length should be 4", true)
	assertEqual(arr[1], "first string")
	assertEqual(arr[2], true)
	assertEqual(arr[3], 76)
	assertEqual(arr[4], false)
end)

test("ParseAttrArray - unquoted string", function()
	local arr, err = Markua.ParseAttrArray('blue')
	assertEqual(err, nil, "Should not return error", true)
	assert(arr ~= nil, "Array should not be nil", true)
	
	assertEqual(#arr, 1, "Array length should be 1", true)
	assertEqual(arr[1], "blue")
end)

test("ParseAttrArray - malformed quoted string", function()
	local arr, err = Markua.ParseAttrArray('"red')
	assert(arr == nil, "Array should be nil")
	assert(type(err) == "string", "Error message should exist")
end)

test("Tags - void", function()
	Markua.RegisterTag("testvoid", true, function(formatter, attr, innerText, processInner)
		local dict = Markua.ParseAttrDict(attr) or {}
		return `{dict.val or "nothing"}`
	end)
	
	local result = Markua.ProcessText('<testvoid val:"hello" />')
	assertEqual(result, "hello")
end)

test("Tags - standard", function()
	Markua.RegisterTag("teststandard", false, function(formatter, attr, innerText, processInner)
		return string.upper(processInner(innerText))
	end)
	
	local result = Markua.ProcessText('<teststandard>hello <testvoid val:"world" /></teststandard>')
	assertEqual(result, "HELLO WORLD")
end)

test("Tags - removal", function()
	Markua.RegisterTag("temptag", true, function() return "TEMP" end)
	assertEqual(Markua.ProcessText('<temptag />'), "TEMP")
	Markua.RemoveTag("temptag")
	assertEqual(Markua.ProcessText('<temptag />'), "<temptag />")
end)

test("ProcessText - malformed tags returned as-is", function()
	local result = Markua.ProcessText('<teststandard>unclosed tag')
	assertEqual(result, "<teststandard>unclosed tag")
end)

test("ProcessText - standard tag treated as void returned as-is", function()
	local result = Markua.ProcessText('<teststandard />')
	assertEqual(result, '<teststandard />')
end)

test("ProcessText - void tag treated as standard returned as-is", function()
	local result = Markua.ProcessText('<testvoid>Hello</testvoid>')
	assertEqual(result, '<testvoid>Hello</testvoid>')
end)

test("ProcessText - unknown tags returned as-is", function()
	local result = Markua.ProcessText('<unknown>Hello</unknown>')
	assertEqual(result, '<unknown>Hello</unknown>')
end)

test("ProcessText - unclosed opening tag", function()
	local result = Markua.ProcessText('<teststandard')
	assertEqual(result, '<teststandard')
end)

test("ProcessText - unopened close tag", function()
	local result = Markua.ProcessText('</teststandard>')
	assertEqual(result, '</teststandard>')
end)

test("ProcessText - stray chevrons", function()
	local result = Markua.ProcessText('<teststandard> a < b </teststandard>')
	assertEqual(result, ' A < B ')
end)

test("ProcessText - nested tags", function()
	Markua.RegisterTag("nestouter", false, function(_, _, inner, process)
		return `outer({process(inner)})`
	end)
	Markua.RegisterTag("nestinner", false, function(_, _, inner, process)
		return `inner({process(inner)})`
	end)
	
	local result1 = Markua.ProcessText('<nestouter>A <nestinner>B</nestinner> C</nestouter>')
	assertEqual(result1, "outer(A inner(B) C)")
	
	local result2 = Markua.ProcessText('<nestouter>A <nestouter>B</nestouter> C</nestouter>')
	assertEqual(result2, "outer(A outer(B) C)")
	
	local result3 = Markua.ProcessText('<nestinner>A <nestinner>B</nestinner> C</nestinner>')
	assertEqual(result3, "inner(A inner(B) C)")
end)

test("ProcessText - complex nesting", function()
	Markua.RegisterTag("nest", false, function(_, _, inner, process)
		return `nest({process(inner)})`
	end)
	
	local text = "<nest> A <nest> B </nest> C <nest> D </nest> E </nest>"
	local result = Markua.ProcessText(text)
	assertEqual(result, "nest( A nest( B ) C nest( D ) E )")
end)

test("ProcessText - caching", function()
	local formatter = Markua.CreateFormatter()
	formatter.CacheEnabled = true
	formatter.UseCache = false
	
	Markua.RegisterTag("cachetest", false, function(_, _, inner) return inner .. "1" end)
	local result1 = Markua.FormatText(formatter, "<cachetest>A</cachetest>")
	assertEqual(result1, "A1")
	
	assert(formatter.FormatCache[1] ~= nil, "Cache should have a value")
	
	formatter.LastFormatIdx = 0
	formatter.UseCache = true
	
	Markua.RegisterTag("cachetest", false, function(_, _, inner) return inner .. "2" end)
	local result2 = Markua.FormatText(formatter, "<cachetest>A</cachetest>")
	assertEqual(result2, result1, "Cache mismatch")
end)

LogService:Info(`Test Results: {passed} Passed, {failed} Failed.`)
