--!native

local httpService = game:GetService("HttpService")
local runService = game:GetService("RunService")

local signal = require(script.Signal)
local easings = require(script.Easing)

local function lerp(min: number, max: number, alpha: number): number
	return min + ((max - min) * alpha)
end

local tweenLibrary = setmetatable({
	activeTweens = {},
	SimulationEnabled = true
}, {
	__index = game:GetService("TweenService")
}) :: TweenService & {
	activeTweens: {[string]: customTween},
	SimulationEnabled: boolean, 
	
	StepTweens: (self, dt: number): (),
	Custom: <A, B>(self, oldValue: A, newValue: B, tweenInfo: TweenInfo) -> (customTween)
}

local tweenableTypes = {
	CFrame = require(script.CFrame),
	ColorSequence = require(script.ColorSequence),
	number = require(script.Types.Number),
	NumberSequence = require(script.Types.NumberSequence),
	Vector3 = require(script.Vectors).Vector3,
	Vector2 = require(script.Vectors).Vector2,
}

local tweenClass = {}
tweenClass.__index = tweenClass

function tweenLibrary:Custom(oldValue, newValue, tweenInfo): customTween
	assert(typeof(oldValue) == typeof(newValue), "what are you doing")
	local funcs = tweenableTypes[typeof(oldValue)]

	local object = {
		oldValue = funcs.deconstruct(nil,oldValue),
		newValue = funcs.deconstruct(nil,newValue),
		tweenInfo = tweenInfo,
		tweenId = httpService:GenerateGUID(false),
		deconstruct = funcs.deconstruct,
		reconstruct = funcs.reconstruct,
		equation = easings[tweenInfo.EasingStyle][tweenInfo.EasingDirection],
		lifetime = 0,
		loopTimes = tweenInfo.RepeatCount,

		Completed = signal.new(),
	}

	return setmetatable(object, tweenClass)
end

function tweenClass:OnUpdate(fn)
	self.OnSteppedReciever = fn
end

local function checkIfEndTween(self)
	if self.loopTimes == -1 then
		self:Pause()
		self.Completed:Fire()
	end
end

local function stepTween(self, dt)
	local tweenInfo = self.tweenInfo
	self.lifetime += if self.isReversing then -dt else dt

	local normalizedTime = self.lifetime / tweenInfo.Time
	local lerpAlpha = self.equation(normalizedTime)

	local currentValue = {}
	for i,v in self.oldValue do
		currentValue[i] = lerp(v, self.newValue[i], lerpAlpha)
	end

	if self.OnSteppedReciever then
		task.spawn(self.OnSteppedReciever, self:reconstruct(currentValue))
	end

	if self.isReversing then
		if normalizedTime <= 0 then
			self.loopTimes -= 1
			self.isReversing = false
			checkIfEndTween(self)
		end
	else
		if normalizedTime >= 1 then
			if tweenInfo.Reverses then
				self.isReversing = true
			else
				self.loopTimes -= 1
			end
			
			if self.loopTimes == -1 then
				self:Pause()
				self.Completed:Fire()
			elseif not self.isReversing then
				self.lifetime = 0
			end
		end
	end
end

function tweenLibrary:StepTweens(dt)
	if not self.SimulationEnabled then return end
	for i,v in self.activeTweens do
		stepTween(v, dt)
	end
end

function tweenClass:Play()
	tweenLibrary.activeTweens[self.tweenId] = self
end

function tweenClass:Pause()
	tweenLibrary.activeTweens[self.tweenId] = nil
end

function tweenClass:Cancel()
	self:Pause()
	self.lifetime = 0
	self.loopTimes = self.tweenInfo.RepeatAmounts
	task.spawn(self.OnSteppedReciever, self:reconstruct(self.oldValue))
end

runService.Heartbeat:Connect(function(dt)
	tweenLibrary:StepTweens(dt)
end)

export type customTween = typeof(tweenLibrary:Custom(table.unpack(...)))

return tweenLibrary