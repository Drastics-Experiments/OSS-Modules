--!native

local sequence = {}

function sequence.deconstruct(self, num: NumberSequence)
	local tbl = {}
	for i = 1, #num.Keypoints do
		local point = num.Keypoints[i]
		tbl[point.Time] = point.Value
	end
	return tbl
end

function sequence.reconstruct(self, points)
	local tbl = {}
	
	local points2 = {}
	
	for i,v in points do
		table.insert(points2, i)
	end

	table.sort(points2, function(a,b)
		return a<b
	end)
	
	for i,v in ipairs(points2) do
		local p = points[v]
		table.insert(tbl, NumberSequenceKeypoint.new(v, p))
	end
	
	return NumberSequence.new(tbl)
end

return sequence