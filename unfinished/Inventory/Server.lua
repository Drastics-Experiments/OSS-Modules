local http = game:GetService("HttpService")

local items = require(script.Parent.Items)

local DEFAULT_PROPS = {
    Amount = 0,
}

local p = script.Parent -- laziness is fire

local addItem = Instance.new("RemoteEvent")
local removeItem = Instance.new("RemoteEvent")
local buyItem = Instance.new("RemoteFunction")
local sellItem = Instance.new("RemoteFunction")
local sendInventory = Instance.new("RemoteEvent")

addItem.Name, buyItem.Name = "AddItem", "BuyItem"
addItem.Parent, removeItem.Parent, sellItem.Parent, sendInventory.Parent, buyItem.Parent = p,p,p,p,p

local activeInventories = {}
local inventory = {}
inventory.__index = inventory

function inventory:CheckWeight(item: string, amount: number)
    local itemData = items[item]
    return self.TotalWeight + (itemData.Weight * amount) <= self.MaxWeight
end

function inventory:CheckSlots(amount)
    return self.TotalItems + amount <= self.MaxSlots
end

function inventory:AddItem(item: string, amount: number)
    local itemData = items[item]
    local totalWeight = self.TotalWeight
    local totalItems = self.TotalItems
    local maxWeight, maxItems = self.MaxWeight, self.MaxSlots

    if not self:CheckWeight(item, amount) then return end
    if not self:CheckSlots(amount) then return end

    local storedData = self.Items[item]
    if not storedData then
        storedData = table.clone(DEFAULT_PROPS)
        self.Items[item] = storedData
    end

    storedData.Amount += amount
    self.TotalItems += amount
    self.TotalWeight += itemData.Weight * amount
    self.Items[item] = storedData
    addItem:FireAllClients(self._identifier, item, amount)
end

function inventory:RemoveItem(item: string, amount: number)
    local itemData = items[item]
    local itemToRemove = self.Items[item]

    if itemToRemove.Amount < amount then return end

    itemToRemove.Amount -= amount
    self.TotalItems -= amount
    self.TotalWeight -= itemData.Weight * amount
    removeItem:FireAllClients(self._identifier, item, amount)
end

function inventory:BuyItem(item: string, amount: number)
    local itemData = Items[item]
    local price = itemData.Cost * amount

    if self.Money < price then return end
    if not self:CheckWeight(item, amount) then return end
    if not self:CheckSlots(amount) then return end

    self.Money -= price
    self:AddItem(item, amount)
end

function inventory:SellItem(item: string, amount: number)
    local itemData = items[item]
    if itemData.Amount < amount then return end

    self.Money += (itemData.Sellback * amount) * self.SellMultiplier
    self:RemoveItem(item, amount)
end

function inventory:Replicate(player: Player)
    local stringify = http:JsonEncode(self)
    local buffered = buffer.fromstring(stringify)

    sendInventory:FireClient(player, buffered)
end

function inventory.New<T>(identifier: T)
    local self = setmetatable({
        Items = {},
        SellMultiplier = 1,
        TotalWeight = 0,
        MaxWeight = 100,
        MaxSlots = 10,
        TotalItems = 0,
        Money = 0,
        _identifier = identifier,
    }, inventory)

    activeInventories[identifier] = self
    return self
end

function inventory.Get<T>(identifier: T)
    return activeInventories[identifier]
end

buyItem.OnServerInvoke = function(player, i, item, v)
    local inventory = activeInventories[i]
    return inventory:BuyItem(item,v)
end

return inventory