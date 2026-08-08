--!native
--!optimize 2
--!divine-intellect
-- https://discord.gg/wx4ThpAsmw

local function string_find(s, pattern, init)
	return string.find(s, pattern, init, true)
end

local function arrayToDict(t, mixedMode, valueOverride, typeStrict)
	local tmp = {}

	if mixedMode then
		for any1, any2 in t do
			if type(any1) == "number" then
				tmp[any2] = valueOverride or true
			elseif type(any2) == "table" then
				tmp[any1] = arrayToDict(any2, mixedMode) -- any1 is Class, any2 is Name
			else
				tmp[any1] = any2
			end
		end
	else
		for _, key in t do
			if not typeStrict or typeStrict and type(key) == typeStrict then
				tmp[key] = true
			end
		end
	end

	return tmp
end

local service = setmetatable({}, {
	__index = function(self, serviceName)
		local o, s = pcall(Instance.new, serviceName)
		local Service = o and s
			or game:GetService(serviceName)
			or settings():GetService(serviceName)
			or UserSettings():GetService(serviceName)

		-- if cloneref then
		-- 	Service = cloneref(Service)
		-- end
		if Service then
			self[serviceName] = Service
		end
		return Service
	end,
})

local global_container
do
	local filename = "UniversalMethodFinder"

	local finder
	finder, global_container = loadstring(
		game:HttpGet("https://raw.githubusercontent.com/luau/SomeHub/main/" .. filename .. ".luau", true),
		filename
	)()

	finder({
		-- request = 'string.find(...,"request",nil,true) and not string.find(...,"internal",nil,true)',
		base64encode = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"encode")and(c(b,"base64")or c(string.lower(tostring(a[2])),"base64"))',
		-- cloneref = 'string.find(...,"clone",nil,true) and string.find(...,"ref",nil,true)',
		-- decompile = '(string.find(...,"decomp",nil,true) and string.sub(...,#...) ~= "s")',
		gethiddenproperty = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"prop",nil,true) and string.sub(...,#...) ~= "s"',
		gethui = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"ui",nil,true)',
		-- getcon = 'string.find(...,"get",nil,true) and (string.find(...,"conn",nil,true) or string.find(...,"sig",nil,true)) and string.sub(...,#(...))=="s"',
		getnilinstances = 'string.find(...,"nil",nil,true) and string.find(...,"get",nil,true) and string.sub(...,#...) == "s"', -- ! Could match some unwanted stuff
		getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"script",nil,true) and string.find(...,"bytecode",nil,true)', --  or string.find(...,"dump",nil,true) and string.find(...[...]
		-- hash = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"hash")and c(string.lower(tostring(a[2])),"crypt")',
		protectgui = 'string.find(...,"protect",nil,true) and string.find(...,"ui",nil,true) and not string.find(...,"un",nil,true)',
		-- setthreadidentity = 'string.find(...,"identity",nil,true) and string.find(...,"set",nil,true)',
	}, true, 10)
end

local identify_executor = identifyexecutor or getexecutorname or whatexecutor

local EXECUTOR_NAME = identify_executor and identify_executor() or ""

-- local cloneref = global_container.cloneref
local gethiddenproperty = global_container.gethiddenproperty
local gethiddenproperty_fallback

-- These should be universal enough
local appendfile = appendfile
local isfile = isfile
local readfile = readfile
local writefile = writefile

local getscriptbytecode = global_container.getscriptbytecode -- * A lot of assumptions are made based on whether this function is defined or not. So in certain edge cases, like if the executor def[...]
local base64encode = global_container.base64encode

-- Decompiler cache & utilities
local HttpService = service.HttpService
local DECOMP_CACHE = {}
local DECOMP_CACHE_PATH = "Tools/ussi_decomp_cache.json"

local function safe_json_decode(s)
    if not s or s == "" then return nil end
    local ok, ret = pcall(HttpService.JSONDecode, HttpService, s)
    if ok and type(ret) == "table" then return ret end
    return nil
end

local function safe_json_encode(t)
    local ok, ret = pcall(HttpService.JSONEncode, HttpService, t)
    if ok then return ret end
    return nil
end

local function load_decomp_cache()
    if isfile and readfile then
        local ok, exists = pcall(isfile, DECOMP_CACHE_PATH)
        if ok and exists then
            local ok2, raw = pcall(readfile, DECOMP_CACHE_PATH)
            if ok2 then
                local tbl = safe_json_decode(raw)
                if tbl then
                    DECOMP_CACHE = tbl
                    return true
                end
            end
        end
    end
    return false
end

local function save_decomp_cache_entry(key, value)
    DECOMP_CACHE[key] = value
    if writefile then
        local json = safe_json_encode(DECOMP_CACHE)
        if json then
            pcall(writefile, DECOMP_CACHE_PATH, json)
        end
    end
end

local function sanitize_source(src)
    if not src then return src end
    -- remove NULs and normalize newlines to LF
    src = string.gsub(src, "\0", "\\0")
    src = string.gsub(src, "\r\n", "\n")
    src = string.gsub(src, "\r", "\n")
    return src
end

if not compile_fn then
    -- No compile function available in this environment; can't validate.
    -- Accept the source but warn so the user knows we couldn't check syntax.
    warn("UniversalSynSaveInstance: syntax validator not available (no loadstring/load). Skipping syntax check.")
    return true, nil
end

local ok, fnOrErr = pcall(compile_fn, src)
if ok and type(fnOrErr) == "function" then
    return true, nil
end

return false, tostring(fnOrErr)

local sharedStringId = 1e15 -- 1 quadrillion, up to 9.(9) quadrillion, in theory this shouldn't ever run out and be enough for all sharedstrings ever imaginable 	-- TODO: worst case, add fallback [...]
local sharedStrings = setmetatable({}, {
	__index = function(self, str)
		local id = base64encode(tostring(sharedStringId)) -- tostring is only needed for built-in base64encode, Luau base64 implementations don't need it as buffers autoconvert
		sharedStringId += 1

		self[str] = id -- ? The value of the md5 attribute is a Base64-encoded key. <SharedString> type elements use this key to refer to the value of the string. The value is the text content, which i[...]
		return id
	end,
})

local inheritedProperties = {}
local defaultInstances = {}
local referents, refSize = setmetatable({}, { __mode = "ks" }), 0 -- ? Roblox encodes all <Item> elements with a referent attribute. Each value is generated by starting with the prefix RBX, follo[...]

local function getRef(instance)
	local ref = referents[instance]
	if not ref then
		ref = refSize
		referents[instance] = ref
		refSize += 1
	end
	return ref
end

local function index(self, index_name)
	return self[index_name]
end

local FULL_VERSION

if not pcall(function()
	FULL_VERSION = version()
end) then
	if not pcall(function()
		FULL_VERSION = settings():GetService("DebugSettings").RobloxVersion
	end) then
		if not pcall(function()
			FULL_VERSION = service.RunService:GetRobloxVersion()
		end) then
			FULL_VERSION = "UNKNOWN"
		end
	end
end

local CLIENT_VERSION = tonumber(string.match(FULL_VERSION, "%d+%.(%d+)")) or 9e9
local __BREAK = "__BREAK" .. service.HttpService:GenerateGUID(false)

local Attribute_Type_Ids =
	{ -- ValueCurveKey & StyleRule.PropertiesSerialize can be used to explore types unsupported by attributes, as they share the same serializer
		["nil"] = 0x01,
		string = 0x02,
		boolean = 0x03,
		int32 = 0x04,
		-- float = 0x05, -- float32
		number = 0x06, -- float64 (double)
		ValueArray = 0x07,
		ValueTable = 0x08, -- Dictionary
		UDim = 0x09,
		UDim2 = 0x0A,
		Ray = 0x0B,
		Faces = 0x0C,
		Axes = 0x0D,
		BrickColor = 0x0E,
		Color3 = 0x0F,
		Vector2 = 0x10,
		Vector3 = 0x11,
		Vector2int16 = 0x12,
		Vector3int16 = 0x13,
		CFrame = 0x14,
		EnumItem = 0x15,
		-- 0x16
		NumberSequence = 0x17,
		NumberSequenceKeypoint = 0x18,
		ColorSequence = 0x19,
		ColorSequenceKeypoint = 0x1A,
		NumberRange = 0x1B,
		Rect = 0x1C,
		PhysicalProperties = 0x1D,
		Color3uint8 = 0x1E,
		Region3 = 0x1F,
		Region3int16 = 0x20,
		Font = 0x21,
		SecurityCapabilities = 0x22,
		Path2DControlPoint = 0x23,
		TweenInfo = 0x24,
		-- InstanceHandle = 0x25,
		-- Path3DControlPoint = 0x26, -- ? not sure
	}


