

local object = require(script.object)

local datastore = {}

function datastore.new(props:{
    bindToClose: boolean,
    datastore: string,
})

    local self = {
        currentlyOpening = 0,
        currentlyClosing = 0,
        datastoreObjects = {},
    }

    return self
end

function datastore.getObject(self, key)
    local newObject = object.new(key)
end