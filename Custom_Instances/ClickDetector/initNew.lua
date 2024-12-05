local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")

local isClient = runService:IsClient()
local isServer = runService:IsServer()

local signal = require(script.Signal)

local function remote(name)
    if isServer then
        local remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = script
    end

    return script:WaitForChild(name)
end

local clicked = remote("clicked")
local create = remote("create")
local delete = remote("delete")

local clickDetector = {}
clickDetector.__index = clickDetector
clickDetector.__metatable = "Locked"
clickDetector.__tostring = function() return "ClickDetector" end
clickDetector.__newindex = function(self, index, value)
    assert(self[index] ~= nil, "Tried to a change property that doesnt exist")
end

local activeDetectors = {}

function clickDetector.new(name, props)
    props = props or {}

    local self = setmetatable({
        MaxActivationDistance = 90 or props.MaxActivationDistance,
        Adornee = props.Adornee,
        CursorIcon = "" or props.CursorIcon.
    }, clickDetector)
    return self
end

if isClient then
end

return clickDetector