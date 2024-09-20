--!native

local sequence = {}

function sequence.deconstruct(self, clr: ColorSequence)
    local tbl = setmetatable({},{})
    local metatable = getmetatable(tbl)
    
    for i = 1, #clr.Keypoints do
        local point = clr.Keypoints[i]
        table.insert(tbl, point.R)
        table.insert(tbl, point.G)
        table.insert(tbl, point.B)
        metatable[i] = point.Time
    end

    return tbl
end

function sequence.reconstruct(self, points)
    local metatable = getmetatable(self.oldValue)
    local tbl = {}
    for i,v in points do
        local div = i % 3
        
        if div == 0 then
            table.insert(tbl, {})
            tbl[#tbl].R = v
        elseif div == 1 then
            tbl[#tbl].G = v
        elseif div == 2 then
            tbl[#tbl].B = v
        end
    end

    for i,v in tbl do
        tbl[i] = ColorSequenceKeypoint.new(metatable[i], Color3.FromRGB(v.R, v.G, v.B))
    end

    return ColorSequence.new(tbl)
end

return sequence