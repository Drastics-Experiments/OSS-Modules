local datastoreService = game:GetService("DatastoreService")

local signal = require(script.Parent.Signal)

local object = {}

local function runHooks(self, event, hook)
    local eventHooks = self.hooks[event]
    if not eventHooks then return end

    local activeHooks = eventHooks[hook]

    for i,v in ipairs(activeHooks) do
        v()
    end
end

function object.new(props: {
    doSessionLock: boolean?,
    template: any,
    datastore: any,
    key: string,
})
    local self = {
        identifier = ``,
        isOpen = false,
        isClosing = false,
        sessionLocking = peops.sessionLocking,

        events = {
            Open = signal.new(),
            Close = signal.new(),
            Read = signal.new(),
            Update = signal.new()
        },

        hooks = {},
    }

    return self
end

function object.Hook(self, hookType, event, fn)
    if not self.hooks[event] then 
        self.hooks[event] = {
            before = {},
            fail = {},
            after = {}
        }
    end

    table.insert(self.hooks[event][hookType], fn)
end

function object.Open(self)
    runHooks(self, "Open", "before")
    
end

function object.Read()
end

function object.Update()
end

function object.Close()
end
    
return object