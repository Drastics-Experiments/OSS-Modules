local function checkIfConvertable(data: {})
    local CanConvert = true
    for i,v in data do
        if typeof(v) == "table" then
            if checkIfConvertable(v) == false then
                CanConvert = false
            end
        else
            local t = type(v)
            if t == "userdata" then
                return false
            end
            
            if t == "function" then
                error("Retard")
            end
        end
    end
    
    return CanConvert
end

local function convertToBuffer(data: {})
    local json = Http:JSONEncode(data)
    local newData = buffer.fromstring(json)
    
    return newData
end

local Client = {
    _activeRemotes = {},
    _initialized = false,
}
local Server = {}
local dataQueue = {}

local RunService = game:GetService("RunService")
local Spawn = require(script.Spawn)

local function disconnect(self)
    self._listeners[self._fn] = nil
    table.clear(self)
end



local function clientFire<T...>(self, ...: T...?)
    local data = {
        [1] = self._name,
        [2] = {...}
    }

    local canConvert = checkIfConvertable(data)
    if canConvert then data = convertToBuffer(data) end
    table.insert(dataQueue, data)
end


function Client.Remote(Name: string, Reliable: boolean?)
    local self = {
        _listeners = {},
        _reliable = Reliable or true,
        _rateLimit = 0,
        _name = Name,
        Fire = clientFire
    }

    return self
end




local function serverFire<_, T...>(self, Players: Player | { Player }, ...: T...?)
    if typeof(Players) ~= "table" then Players = {Players} end
    local data = {
        [1] = self._name,
        [2] = {...}
    }

    local canConvert = checkIfConvertable(data)
    if canConvert then data = convertToBuffer(data) end
    table.insert(dataQueue, {
        Players = Players,
        Data = data
    })
end

local function serverListen(self, fn: <_, T...>(Player: Player, ...: T...?))
    self._listeners[tostring(fn)] = fn

    return {
        _listeners = self._listeners,
        _fn = tostring(fn),
        Disconnect = disconnect
    }
end

function Server.Remote(Name: string, Reliable: boolean?)
    local self = {
        _listeners = {},
        _reliable = Reliable or true,
        _rateLimit = 0,
        _name = Name,

        Fire = serverFire,
        Listen = serverListen
    }

    return self
end


local FRAME_RATE = 1/60
local Network = {}

function Network.Server()
    if not Server._initialized then
        local Remote = Instance.new("RemoteEvent")
        local UnreliableRemote = Instance.new("UnreliableRemoteEvent")
        Remote.Parent = script
        UnreliableRemote.Parent = script

        Server._initialized = true
    end
    
    return Server
end

function Network.Client()
    if not script:FindFirstChild("RemoteEvent") and not Client._initialized then
        local running = coroutine.running()
        warn("Server is not Initialized. Currently Yielding")

        script.ChildAdded:Once(function()
            coroutine.resume(running)
        end)

        coroutine.yield()
        Client._initialized = true
    end

    return Client
end

return table.freeze(Network)