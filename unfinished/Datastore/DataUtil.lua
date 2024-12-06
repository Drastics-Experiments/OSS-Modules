local datastoreService = game:GetService("DatastoreService")
local memoryStoreService = game:GetService("MemoryStoreService")

local dataUtil = {}
local activeDatastores = {}

function dataUtil.getStore(key)
    if not activeDatastores[key] then
        activeDatastores[key] = datastoreService:GetDatastore(key)
    end

    return activeDatastores[key]
end

function dataUtil.getAsync(store, key)
end

function dataUtil.setAsync(store, key, data)
end

function dataUtil.lockDatstore()
end

function dataUtil.unlockDatastore()
end

function dataUtil.isLocked()
end
