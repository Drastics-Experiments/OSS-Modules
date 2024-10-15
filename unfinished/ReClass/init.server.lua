local selection = game:GetService("Selection")

local metcher = require(script.Matcher)
local getRelativeProperties = require(script.getRelativeProperties)

local guiModules = script.guiModules

selection.SelectionChanged:Connect(function()
end)