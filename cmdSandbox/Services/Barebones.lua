

local replicatedStorage = {}
local methods = {}
local meta

setmetatable(replicatedStorage, {
    properties = {
        Name = "ReplicatedStorage",
        Parent = game,
    },
    children = {},

    __tostring = function()
        return "ReplicatedStorage"
    end,

    __index = function(self, index)
        assert(typeof(index) == "string", "Only string indexes are allowed")
        local result = methods[index] or meta.properties[index] or meta.children[index]
        return result
    end,

    __newindex = function(self, index, value)
        assert(typeof(value) ~= "nil" or typeof(value) ~= "Instance")
        
    end
})

meta = getmetatable(replicatedStorage)
return replicatedStorage