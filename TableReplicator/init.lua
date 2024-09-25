local runService = game:GetService("RunService")
local isServer, isClient = runService:IsServer(), runService:IsClient()

local instanceManager = require(script.instanceManager)
local signal = require(script.signal)
local bufferLib = require(script.buffer)

local tableReplicator = {}
local methods = {}

function __newindex(self, index, value)
    local metatable = getmetatable(self)

    local propsignals = metatable.propertysignals
    local data = metatable.__index

    local oldValue = data[index]

    if typeof(index) == "Instance" then
        instanceManager.registerInstance(index)
    end

    if typeof(value) == "Instance" then
        instanceManager.registerInstance(value)
    elseif typeof(value) == "table" then
        local newMetatable = createMetatable()
        getmetatable(newMetatable).base = metatable.base
        for i,v in value do
            newMetatable[i] = v
        end

        value = newMetatable
    end

    data[index] = value
    if value ~= oldValue then
        self:FireChanged(index, value, oldValue)
    end
end

function createMetatable()
    local self = setmetatable({
        Changed = signal.new()
    }, {
        __index = table.clone(methods),
        __newindex = __newindex,
        propertysignals = {},
        whitelistedPlayers = {}
    })

    local metatable = getmetatable(self)
    metatable.id = tostring(self)
    
    return self
end

function tableReplicator.new(tableProps: {
    Name: string,
    InitialData: {}?,
    PlayersToReplicate: { Player }?
})

local self = createMetatable()
local metatable = getmetatable(self)
if InitialData then
    for i,v in InitialData do
        self[i] = v
    end
end

if isServer then
    metatable.whitelistedPlayers = PlayersToReplicate
    for i,v in PlayersToReplicate do
        self:ReplicateTable(v)
    end
end

return metatable
end

function methods:ReplicateTable(player: Player)

end

local function rawRecursive(self, convertInstances)
    local data = {}
    for i,v in self do
        if typeof(v) == "table" then
            data[i] = rawRecursive(v, convertInstances)
        elseif typeof(v) == "Instance" then
            if convertInstances then
                data[i] = instanceManager.getIdFromInstance(v)
            else 
                data[i] = v
            end
        else
            data[i] = v
        end
    end
    return data
end

function methods:GetRawTable()
    local metatable = getmetatable(self)
    local base = metatable.base
    local rawData = rawRecursive(self, false)
    return rawData
end


function methods:GetNetworkableTable()
end

function methods:FireChanged(index, value, oldValue)
    local metatable = getmetatable(self)

    self.Changed:Fire(index,value,oldValue)
    if metatable.propertysignals[index] then
        metatable.propertysignals[index]:Fire(value, oldValue)
    end
end

function methods:GetPropertyChangedSignal(property: string)
    local metatable = getmetatable(self)
    local propertysignals = metatable.propertysignals

    if not propertysignals[property] then
        propertysignals[property] = signal.new()
    end

    return propertysignals[property]
end

return tableReplicator