--!native

local squence = {}

function sequence.deconstruct(self, num: NumberSequence)
    local tbl = {}
    for i = 1, #num.Keypoints do
        local point = num.Keypoints[i]
        tbl[point.Time] = point.Value
    end
end

function sequence.reconstruct(self, points)
    local tbl = {}
    for i,v in ipairs(points) do
        table.insert(tbl, NumberSequenceKeypoint.new(i, v))
    end
    return NumberSequence.new(tbl)
end

return sequence