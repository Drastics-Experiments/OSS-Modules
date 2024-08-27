local Module = {}
local Index = {}

local function NewIndex(self, index, value)
	if index ~= "OnInvoke" then return end
	if typeof(value) ~= "function" then return end
	
	if index == "OnInvoke" then
		rawset(self, index, value)
		
		for i,v in self._currentYield do
			coroutine.resume(v)
		end
	end
	
	return value
end

function Module.new()
	local self = setmetatable({
		OnInvoke = nil,
		Yield = true,
		_currentYield = {}
	}, {
		__index = Index,
		__newindex = NewIndex,
		__type = "Invokable"
	})
	
	return self
end

function Index:Invoke(...)
	local running = coroutine.running()
	if self.OnInvoke == nil then 
		if self.Yield then
			table.insert(self._currentYield, running)
			coroutine.yield()
		else return nil end
	end
	
	return self.OnInvoke(...)
end

return Module