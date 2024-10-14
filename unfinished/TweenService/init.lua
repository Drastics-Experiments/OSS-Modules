--!native

local tweenService = game:GetService("TweenService")
local httpService = game:GetService("HttpService")
local runService = game:GetService("RunService")

local signal = require(script.Signal)
local easings = require(script.Easing)

local function lerp(min: number, max: number, alpha: number): number
	return min + ((max - min) * alpha)
end

local tweenLibrary = {}
local activeTweens = {}
local tweenableTypes = {
	CFrame = require(script.CFrame),
	ColorSequence = require(script.ColorSequence),
	number = require(script.Types.Number),
	NumberSequence = require(script.Types.NumberSequence),
	Vector3 = require(script.Vectors).Vector3,
	Vector2 = require(script.Vectors).Vector2,
}

function tweenLibrary.TweenInfo(
	time: number, 
	easingStyle: Enum.EasingStyle?, 
	easingDirection: Enum.EasingDirection?, 
	repeatAmounts: number?, 
	reverse: boolean?, 
	delay: number?
)
	return {
		Time = time,
		EasingStyle = easingStyle or Enum.EasingStyle.Sine,
		EasingDirection = easingDirection or Enum.EasingDirection.Out,
		RepeatAmounts = repeatAmounts or 0,
		Reverse = reverse or false,
		delay = delay or 0,
	} 
end

local methods = {}
methods.__index = customMethods
function tweenLibrary.Create(oldValue, newValue, tweenInfo)
	assert(typeof(oldValue) == typeof(newValue), "what are you doing")
	local t = typeof(oldValue)
	local funcs = tweenableTypes[t]

	local self = {
		oldValue = funcs.deconstruct(nil,oldValue),
		newValue = funcs.deconstruct(nil,newValue),
		tweenInfo = tweenInfo,
		tweenId = httpService:GenerateGUID(false),
		deconstruct = funcs.deconstruct,
		reconstruct = funcs.reconstruct,
		equation = easings[tweenInfo.EasingStyle][tweenInfo.EasingDirection],
		lifetime = 0,
		loopTimes = tweenInfo.RepeatAmounts,
		
		Completed = signal.new(),
	}

	setmetatable(self, methods)
	return self
end

function methods:OnUpdate(fn)
	self.OnSteppedReciever = fn
end

local function stepTween(self, dt)
	local tweenInfo = self.tweenInfo
	self.lifetime += (tweenInfo.isReversing and -dt) or dt

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
			if self.loopTimes == -1 then
				self:Stop()
				self.Completed:Fire()
			end
		end
	else
		if normalizedTime >= 1 then
			if tweenInfo.Reverse then
				self.isReversing = true
			elseif self.loopTimes == -1 then
				self:Stop()
				self.Completed:Fire()
			else
				self.lifetime = 0
			end
		end
	end
end
.
function methods:Play(self)
	activeTweens[self.tweenId] = self
end

function methods:Pause(self)
	activeTweens[self.tweenId] = nil
end

function methods:Cancel(self)
	self:Pause()
	self.lerpAlpha = 0
	task.spawn(self.OnSteppedReciever, self:reconstruct(self.oldValue))
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
	for i,v in activeTweens do
		stepTween(v, dt)
	end
end)

return tweenLibrary