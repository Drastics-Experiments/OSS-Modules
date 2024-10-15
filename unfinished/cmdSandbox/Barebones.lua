local signal = require(script.Parent.Signal)

local barebones = {}

local defaultProperties = {
    Name = "",
    Parent = game,
    Changed = "Event",
    ChildAdded = "Event",
    ChildRemoved = "Event",

}

local defaultMethods = {}
function defaultMethods:GetChildren()
    return getmetatable(self).children
end

function defaultMethods:GetDescendants()
    local children = table.clone(getmetatable(self).children)

    for i,v in children do
        for i2, v2 in v:GetDescendants() do
            table.insert(children, v2)
        end
    end

    return children
end

function defaultMethods:FindFirstChild(name, recursive)
    for i,v in (recursive == true and self:GetDescendants()) or self:GetChildren() do
        if v.Name == name then
            return v
        end
    end
end

function defaultMethods:WaitForChild(name: string)
    local thread = coroutine.running()
    local foundChild = self:FindFirstChild(name, false)

    if not foundChild then
        local connection
        connection = self.ChildAdded:Connect(function(child)
            if child.Name == name then
                task.spawn(thread, child)
                connection:Disconnect()
            end
        end)
        return coroutine.yield()
    end
    
    return foundChild
end

function defaultMethods:GetPropertyChangedSignal(property: string)
    local meta = getmetatable(self)
    local signals = meta.signals

    if not signals[property] then
        signals[property] = signal.new()
    end

    return signals[property]
end

function defaultMethods:SetAttribute(attribute: string, value)
    assert(type(attribute) == 'string')
    getmetatable(self).attributes[attribute] = value
end

function defaultMethods:GetAttribute(attribute)
    return getmetatable(self).attributes[attribute]
end

function defaultMethods:GetAttributes()
    return table.freeze(table.clone(getmetatable(self).attributes))
end

type serviceData = {
    methods: {
        [string]: (...any) -> (...any)
    },

    properties: {
        [string]: any
    },
}

local function __index(self, index)
    local meta = getmetatable(self)
    local result = meta.properties[index] or meta.methods[index] or meta.children[index]
    return result
end

local function __newindex(self, index, value)
    local t = typeof(value)
    assert(t == "string" or t == "number" or t == "boolean" or t == "Instance")

    local meta = getmetatable(self)
    local props = meta.properties

    local oldValue = props[index]
    assert(typeof(oldValue) ~= t)

    if value ~= oldValue then
        self.Changed:Fire()
        if meta.signals[index] then
            meta.signals[index]:Fire()
        end
    end

    return value
end

local function __tostring(self)
    return self.Name
end

function barebones.createService(serviceData)
    local properties = table.clone(defaultProperties)

    for i,v in properties do
        if v == "Event" then
            properties[i] = signal.new()
        end
    end

    local self = setmetatable({}, {
        __index = __index,
        __newindex = __newindex,
        __tostring = __tostring,

        attributes = {},
        properties = properties,
        children = {},
        signals = {},
        methods = table.clone(defaultMethods)
    })
end

local instanceClass = {}
instanceClass.__newindex = function(self, index, value)
    local creation = self.__instance
    if index == "Parent" then
        if typeof(value) == "table" then
            value:ChildAdded(self)
            value = value:GetFolder()
        end
    end
    creation[index] = value
end

instanceClass.__index = function(self, index)
    return self.__instance[index]
end

function barebones.newInstance(instanceType, props)
    local creation = Instance.new(instanceType)
    local self = setmetatable({__instance = creation}, instanceClass)
    return self
end

return barebones