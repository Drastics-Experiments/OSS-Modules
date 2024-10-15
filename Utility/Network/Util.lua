local Http = game:GetService("HttpService")

local function checkIfConvertable(data: {})
	local CanConvert = true
	for i,v in data do
		if typeof(v) == "table" then
			if checkIfConvertable(v) == false then
				CanConvert = false
			end
		else
			local t = type(v)
			if t == "userdata" then
				return false
			end

			if t == "function" then
				error("Retard")
			end
		end
	end

	return CanConvert
end

local function convertToBuffer(data: {})
	local json = Http:JSONEncode(data)
	local newData = buffer.fromstring(json)

	return newData
end

return {
	convertToBuffer = convertToBuffer,
	checkIfConvertable = checkIfConvertable
}