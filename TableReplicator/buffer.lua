local http = game:GetService("HttpService")
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
        local stringify = http:JsonEncode(tbl)
        local buffered = buffer.fromstring(stringify)
        return buffered
    end

    return "failed"
end

function bufferLib.DecompressTable(bfr)
    if typeof(bfr) == "buffer" then
        return http:JsonDecode(buffer.tostring(bfr))
    end
    
    return "failed"
end

return bufferLib