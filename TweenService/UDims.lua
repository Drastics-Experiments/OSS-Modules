local udim2 = {}

function udim2.deconstruct(self, udim2)
    return {udim2.X.Scale, udim2.X.Offset, udim2.Y.Scale, udim2.Y.Offset}
end

function udim2.reconstruct(self, points)
    return UDim2.new(table.unpack(points))
end

local udim = {}

function