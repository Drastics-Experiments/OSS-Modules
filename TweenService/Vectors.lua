--!native

local vector = {}

function vector.deconstruct(self, vector3)
    return {vector3.X, vector3.Y, vector3.Z}
end

function vector.reconstruct(self, points)
    return Vector3.new(table.unpack(points))
end

local vector2 = {}
function vector2.deconstruct(self, vector)
    return {vector.X, vector.Y}
end

function vector2.reconstruct(self, points)
    return Vector2.new(table.unpack(points))
end

return {Vector3 = vector, Vector2 = vector2}