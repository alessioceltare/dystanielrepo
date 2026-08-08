--!native
--!optimize 2
--!divine-intellect
-- https://discord.gg/wx4ThpAsmw

--[[
    UniversalSynSaveInstance
    A robust script for serializing Roblox instances and their properties.
    This script is designed to work across various executors by dynamically finding required functions.
--]]

local UniversalSynSaveInstance = {}

-- Define compile_fn if possible, otherwise it will be nil
local compile_fn = loadstring

-- Helper Functions
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
                tmp[any1] = arrayToDict(any2, mixedMode)
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

-- Service Metatable for dynamic service retrieval
local service = setmetatable({}, {
    __index = function(self, serviceName)
        local success, s = pcall(Instance.new, serviceName)
        local Service = success and s
            or game:GetService(serviceName)
            or settings():GetService(serviceName)
            or UserSettings():GetService(serviceName)
        
        if Service then
            self[serviceName] = Service
        end
        return Service
    end,
})

-- Global Environment Setup
local global_container
do
    local filename = "UniversalMethodFinder"
    local success, finder = pcall(function()
        return loadstring(
            game:HttpGet("https://raw.githubusercontent.com/luau/SomeHub/main/" .. filename .. ".luau", true),
            filename
        )()
    end)

    if not success then
        warn("UniversalSynSaveInstance: Failed to load UniversalMethodFinder. Some features may not work.")
        global_container = {}
    else
        global_container = finder
        finder({
            base64encode = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"encode")and(c(b,"base64")or c(string.lower(tostring(a[2])),"base64"))',
            gethiddenproperty = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"prop",nil,true) and string.sub(...,#...) ~= "s"',
            gethui = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"ui",nil,true)',
            getnilinstances = 'string.find(...,"nil",nil,true) and string.find(...,"get",nil,true) and string.sub(...,#...) == "s"',
            getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"script",nil,true) and string.find(...,"bytecode",nil,true)',
            protectgui = 'string.find(...,"protect",nil,true) and string.find(...,"ui",nil,true) and not string.find(...,"un",nil,true)',
        }, true, 10)
    end
end

local identify_executor = identifyexecutor or getexecutorname or whatexecutor
local EXECUTOR_NAME = identify_executor and identify_executor() or ""

-- Global Functions (with fallbacks)
local gethiddenproperty = global_container.gethiddenproperty
local appendfile = appendfile
local isfile = isfile
local readfile = readfile
local writefile = writefile
local getscriptbytecode = global_container.getscriptbytecode
local base64encode = global_container.base64encode

-- Decompiler Cache & Utilities
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
    src = string.gsub(src, "\0", "\\0")
    src = string.gsub(src, "\r\n", "\n")
    src = string.gsub(src, "\r", "\n")
    return src
end

-- This function now correctly handles the case where compile_fn might be nil
local function validate_syntax(src)
    if not compile_fn then
        warn("UniversalSynSaveInstance: syntax validator not available (no loadstring/load). Skipping syntax check.")
        return true, nil
    end

    local ok, fnOrErr = pcall(compile_fn, src)
    if ok and type(fnOrErr) == "function" then
        return true, nil
    end
    return false, tostring(fnOrErr)
end

-- Serialization State
local sharedStringId = 1e15
local sharedStrings = setmetatable({}, {
    __index = function(self, str)
        local id = base64encode(tostring(sharedStringId))
        sharedStringId = sharedStringId + 1
        self[str] = id
        return id
    end,
})

local inheritedProperties = {}
local defaultInstances = {}
local referents, refSize = setmetatable({}, { __mode = "ks" }), 0

local function getRef(instance)
    local ref = referents[instance]
    if not ref then
        ref = refSize
        referents[instance] = ref
        refSize = refSize + 1
    end
    return ref
end

-- Version Detection
local FULL_VERSION
if not pcall(function() FULL_VERSION = version() end) then
    if not pcall(function() FULL_VERSION = settings():GetService("DebugSettings").RobloxVersion end) then
        if not pcall(function() FULL_VERSION = service.RunService:GetRobloxVersion() end) then
            FULL_VERSION = "UNKNOWN"
        end
    end
end
local CLIENT_VERSION = tonumber(string.match(FULL_VERSION, "%d+%.(%d+)")) or 9e9
local __BREAK = "__BREAK" .. service.HttpService:GenerateGUID(false)

-- Attribute Type IDs
local Attribute_Type_Ids = {
    ["nil"] = 0x01,
    string = 0x02,
    boolean = 0x03,
    int32 = 0x04,
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
    NumberSequence = 0x17,
    NumberSequenceKeypoint = 0x18,
    ColorSequence = 0x19,
    ColorSequenceKeypoint = 0x1A,
    NumberRange = 0x1B,
    Rect = 0x1C,
    PhysicalProperties = 0x0D,
    Color3uint8 = 0x1E,
    Region3 = 0x1F,
    Region3int16 = 0x20,
   
