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
	looped: boolean?, 
	reverse: boolean?, 
	delay: number?
)
	return {
		Time = time,
		EasingStyle = easingStyle or Enum.EasingStyle.Sine,
		EasingDirection = easingDirection or Enum.EasingDirection.Out,
		Looped = looped or false,
		Reverse = reverse or false,
		delay = delay or 0,
	} end

function tweenLibrary.Create()
end

local customMethods = {}
customMethods.__index = customMethods
function tweenLibrary.CreateCustom(oldValue, newValue, tweenInfo)
	assert(typeof(oldValue) == typeof(newValue), "what are you doing")
	local t = typeof(oldValue)
	local funcs = tweenableTypes[t]
	print(tweenInfo)
	local self = {
		lerpAlpha = 0,
		oldValue = funcs.deconstruct(nil,oldValue),
		newValue = funcs.deconstruct(nil,newValue),
		tweenInfo = tweenInfo,
		currentValue = {},
		tweenId = httpService:GenerateGUID(false),
		deconstruct = funcs.deconstruct,
		reconstruct = funcs.reconstruct,
		equation = easings[tweenInfo.EasingStyle][tweenInfo.EasingDirection],
		lifetime = 0,
		
		Play = Play,
		Pause = Pause,
		
		Completed = signal.new(),
		Cancelled = signal.new(),
		Resumed = signal.new(),
		Paused = signal.new()
	}

	setmetatable(self, customMethods)
	return self
end

function customMethods:OnUpdate(fn)
	self.OnSteppedReciever = fn
end

function customMethods:_stepTween(dt)
	local tweenInfo = self.tweenInfo
	self.lifetime += dt
	self.lerpAlpha = self.equation(self.lifetime / self.tweenInfo.Time)
	
	for i,v in self.oldValue do
		self.currentValue[i] = lerp(v, self.newValue[i], self.lerpAlpha)
	end
	
	if self.OnSteppedReciever then
		task.spawn(self.OnSteppedReciever, self:reconstruct(self.currentValue))
	end
	
	if self.lifetime >= self.tweenInfo.Time then
		if self.looped then
			self:Cancel()
			self:Play()
		else
			self:Pause()
			self.Completed:Fire()
		end
	end
end

function Play(self)
	if self.lerpAlpha > 0 then
		self.Resumed:Fire()
	end

	activeTweens[self.tweenId] = self
end

function Pause(self)
	activeTweens[self.tweenId] = nil

	if self.lerpAlpha < 1 then
		self.Paused:Fire()
	end
end

function Cancel(self)
	self:Pause()
	self.lerpAlpha = 0
	task.spawn(self.OnSteppedReciever, self:reconstruct(self.oldValue))
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
	for i,v in activeTweens do
		v:_stepTween(dt)
	end
end)

return tweenLibrary