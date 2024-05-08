local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local DatastoreModule = require(script.DatastoreModule)
local Signal = require(script.Signal)

local GameSaver = {}

local function FindOrNew(a,b,c)
    return DatastoreModule.find(a,b,c) or DatastoreModule.new(a,b,c)
end

function GameSaver.GetPlayerSavedGame(sender: Player, Map: string)
    local Data = FindOrNew("PlayerData", sender.UserId)
end


return GameSaver