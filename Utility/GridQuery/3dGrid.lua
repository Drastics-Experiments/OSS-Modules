-- vector library cuz not using roblox studio while writing this

local CELL_SIZE = 5

local grid = {
    ActiveCells = {},
    DataStorage = {},
}

local function checkOrAdd(tbl, num)
    tbl[num] = tbl[num] or {}
    return tbl[num]
end

-- WorldToGrid()
local function toGrid(num)
    return math.floor(num / CELL_SIZE)
end

local function loopRecursive(tbl, callback)
	for i,v in tbl do
		if type(i) == "table" then
			loopRecursive(i, callback)
			callback(i, i, tbl)
		end
		if type(v) == "table" then
			loopRecursive(v, callback)
			callback(v, i, tbl)
		end
	end
end
    
local function isTableEmpty(tbl)
    for i, v in tbl do
        return false
    end

    return true
end

function grid:Add(pos, tag, data)
    assert(typeof(pos) == "Vector3", "Expected Vector3, got " .. typeof(pos))
    assert(tag ~= nil, "Arguement 2 was not provided")
    assert(data ~= nil, "Arguement 3 was not provided")

    if type(data) ~= "table" then
        warn("Using DataTypes other than tables may result in unexpected behavior")
    end

    local xCell = checkOrAdd(self.ActiveCells, toGrid(pos.X))
    local yCell = checkOrAdd(xCell, toGrid(pos.Y))
    local zCell = checkOrAdd(yCell, toGrid(pos.Z))

    local tagData = checkOrAdd(zCell, tag)
    tagData[tostring(data)] = pos

    self.DataStorage[tostring(data)] = data
end

function grid:Update(position, tag, data)
    assert(typeof(position) ~= "Vector3", "Expected Vector3, got: " .. typeof(position))
    assert(tag ~= nil, "Arguement 2 was not provided")
    assert(data ~= nil, "Arguement 3 was not provided")

    self:Remove(position, tag, data)
    self:Add(position, tag, data)
end

function grid:Remove(pos, tag, data)
    assert(typeof(pos) == "Vector3", "Expected Vector3, got: " .. typeof(pos))
    assert(tag ~= nil, "Arguement 2 was not provided")
    assert(data ~= nil, "Arguement 3 was not provided")

    local cell = self:FindCell(vector.floor(pos / CELL_SIZE), tag)
    if not cell then return end

    cell[tostring(data)] = nil
    self.DataStorage[tostring(data)] = nil
end

function grid:Clear()
	loopRecursive(self.ActiveCells, table.clear)
	loopRecursive(self.DataStorage, table.clear)
    table.clear(self.ActiveCells)
	table.clear(self.DataStorage)
end

function grid:FindCell(position, tag)
    assert(typeof(position) == "Vector3", "Expected Vector3, got: " .. typeof(position))
    assert(tag ~= nil, "Arguement 2 was not provided")

    local xCell = self.ActiveCells[position.X]
    if not xCell then return end
    
    local yCell = xCell[position.Y]
    if not yCell then return end

    local zCell = yCell[position.Z]
    if not zCell then return end

    return zCell[tag]
end

function grid:GarbageCollect()
    loopRecursive(self.ActiveCells, function(tbl, index, parent)
        if not isTableEmpty(tbl) then
            return
        end

        parent[index] = nil
    end)
end

function grid:FindCellsInRadius(position, radius, tag)
    assert(typeof(position) == "Vector3", "Expected Vector3, got: " .. typeof(position))
    assert(type(radius) == "number", "Expected number, got: " .. type(radius))
    assert(tag ~= nil, "Arguement 3 was not provided")

    local foundCells = {}

    local cellOrigin = vector.floor(position / CELL_SIZE)
    local cellRadius = math.floor(radius / CELL_SIZE)
    local cellRadiusVector3 = vector.one * cellRadius

    local start = cellOrigin - cellRadiusVector3
    local ending = cellOrigin + cellRadiusVector3

    for x = start.X, ending.X do
        for y = start.Y, ending.Y do
            for z = start.Z, ending.Z do
                local currentCellPosition = vector.create(x,y,z)
                local cell = self:FindCell(currentCellPosition, tag)

                if cell and vector.magnitude(currentCellPosition - cellOrigin) <= cellRadius then
                    table.insert(foundCells, cell)
                end
            end
        end
    end

    return foundCells
end

function grid:FindObjectsInRadius(position, radius, tag)
    assert(typeof(position) == "Vector3", "Expected Vector3, got: " .. typeof(position))
    assert(type(radius) == "number", "Expected number, got: " .. type(radius))
    assert(tag ~= nil, "Arguement 3 was not provided")

    local foundObjects = {}

    for _, cell in self:FindCellsInRadius(position, radius, tag) do
        for objectName, objectPosition in cell do
            if vector.magnitude(objectPosition - position) <= radius then
                table.insert(foundObjects, self.DataStorage[objectName])
            end
        end
    end

    return foundObjects
end

return grid