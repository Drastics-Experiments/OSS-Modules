--!native

local cf = {}

function cf.deconstruct(self, cframe)
    return {cframe:GetComponents()}
end

function cf.reconstruct(self, components)
    return CFrame.new(table.unpack(components))
end

return cf