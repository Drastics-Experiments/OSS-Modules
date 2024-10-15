local httpService = game:GetService("HttpService")
local url = "https://anaminus.github.io/rbx/json/api/latest.json"

local classes = {}
local succeeded, result = false, false

while not succeeded do
    succeeded, result = pcall(function()
        return httpService:GetAsync(url)
    end)

    if not succeeded then warn(result) task.wait(3) end
end

local decodedData = httpService:JSONDecode(result)
for _, entry in ipairs(decodedData) do
    local entryType = entry.type

    if entryType == "Class" then

        local className = entry.Name
        local classData = {}
        local Superclass = entry.Superclass

        if Superclass then
            local superclassData = Classes[Superclass]

            if superclassData then
                for _, data in ipairs(superclassData) do
                    table.insert(classData, data)
                end
            end
        end

        classes[className] = classData
    elseif entryType == "Property" then
        local className = entry.Class
        local propertyName = entry.Name

        if next(entry.tags) then return end
        
        local classData = classes[className]

        if classData then
            table.insert(classData, propertyName)
        end
    end
end

return function(className: string)
    return classes[className]
end