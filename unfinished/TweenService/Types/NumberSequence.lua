--!native

local sequence = {}

function sequence.deconstruct(self, num: NumberSequence)
	local tbl = {}
	for i = 1, #num.Keypoints do
		local point = num.Keypoints[i]
		table.insert(tbl, point.Value)
		table.insert(tbl, point.Time)
	end
	return tbl
end

function sequence.reconstruct(self, points)
	local tbl = {}
	
	for i = 2, #points, 2 do
		table.insert(tbl, NumberSequenceKeypoint.new(points[i]), points[i - 1])
	end
	
	return NumberSequence.new(tbl)
end

return sequence