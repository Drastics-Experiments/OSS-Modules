--!native

local http = game:GetService("HttpService")
local compression = require(script.Parent.compress)
local compressionConfig = {
	level = 4
}
local bufferLib = {}

local function checkIfCanCompress(tbl)
	local canCompress = true
	for i,v in tbl do
		if type(v) == "userdata" then
			return false
		elseif type(v) == "table" then
			canCompress = checkIfCanCompress(v)
		elseif type(v) == "function" then
			return false
		end
	end
	return canCompress
end

function bufferLib.CompressTable(tbl)
	if checkIfCanCompress(tbl) then
		local stringify = http:JSONEncode(tbl)

		if compressionConfig.level > 0 then
			stringify = compression.ZLib.Compress(stringify, compressionConfig)
		end

		local buffered = buffer.fromstring(stringify)
		return buffered
	end

	return "failed"
end

function bufferLib.DecompressTable(bfr)
	if typeof(bfr) == "buffer" then
		bfr = buffer.tostring(bfr)
		
		if compressionConfig.level > 0 then
			bfr = compression.ZLib.Decompress(bfr, compressionConfig)
		end

		return http:JSONDecode(bfr)
	end

	return "failed"
end

return bufferLib
