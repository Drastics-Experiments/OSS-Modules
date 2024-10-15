local getProperties = require(script.Parent.getProperties)

local matcher = {}

function matcher.getRelativeProperties<instance1, instance2>(a: instance1, b: instance2)
    local props1, props2 = getProperties(a.ClassName), getProperties(b.ClassName)

    local tbl1, tbl2 = {}, {}
    for i,v in props1 do
        tbl1[v] = 1
    end
    for i,v in props2 do
        tbl2[v] = 1
    end

    local matches = {}
    for i,v in tbl1 do
        if tbl2[i] then
            matches[i] = 1
        end
    end

    return matches
end

function matcher.replaceProperties(a,b)
    local matches = matcher.getRelativeProperties(a,b)
    for i,v in matches do
        b[i] = a[i]
    end
end

return matcher