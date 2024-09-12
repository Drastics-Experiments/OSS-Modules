local p = script.Parent
local w = p.WaitForChild -- peak laziness

local addItem = w(p, "AddItem")
local buyItem = w(p, "BuyItem")
local sendInventory = w(p, "SendInventory")


local inventory = {}
inventory.__index = inventory

function inventory:BuyItem(item: string, amount: number)
    return buyItem:invokeServer(item, amount)
end

local function createInventory(identifier: any)
    local self = setmetatable({
        Items = {},
        Money = 0,
        MaxSlots = 10,
        MaxWeight = 100,
        TotalItems = 0,
        TotalWeight = 0,
        SellMultiplier = 1,
        _identifier = identifier
    }, inventory)
    return self
end

sendInventory.OnClientEvent:Connect(createInventory)