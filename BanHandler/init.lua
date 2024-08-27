local Players = game:GetService("Players")

local RETRY_AMOUNT = 5
local RETRY_DELAY = 6

local BanManager = {}

local TimeUnitIndex  = {
	Second = 1,
	Minute = 60,
	Hour = 3600,
	Day = 86400,
	Week = 604800,
	Month = 2592000,
	Year = 31536000
}

local function GetCorrectDuration(Amount, TimeUnit)
	return Amount * TimeUnitIndex[TimeUnit]
end

local function RepeatPcall(...)
	local success, result

	for i = 1, RETRY_AMOUNT do
		success, result = pcall(...)
		if success then break end
		task.wait(RETRY_DELAY)
	end
	
	return success, result
end

type ApplyBanConfig = {
	UserIds: { number },
	ApplyToUniverse: boolean?,
	Duration: number,
	PublicReason: string,
	PrivateReason: string?,
	ExcludeAltAccounts: boolean?,
	TimeUnit: string
}
function BanManager.BanAsync(Config: ApplyBanConfig)
	local data = {
		UserIds = Config.UserIds,
		ApplyToUniverse = Config.ApplyToUniverse or true,
		Duration = GetCorrectDuration(Config.Duration, Config.TimeUnit),
		DisplayReason = Config.PublicReason,
		PrivateReason = Config.PrivateReason or Config.PublicReason,
		ExcludeAltAccounts = Config.ExcludeAltAccounts or false
	}
	
	local success, result = RepeatPcall(Players.BanAsync, Players, data)	
	return (success and "Success") or "Failed"
end

type RemoveBanConfig = {
	UserIds: { number },
	ApplyToUniverse: boolean?, 
}
function BanManager.UnbanAsync(Config: RemoveBanConfig)
	local data = {
		UserIds = Config.UserIds,
		ApplyToUniverse = Config.ApplyToUniverse or true
	}
	
	local success, result = RepeatPcall(Players.UnbanAsync, Players, data)
	return (success and "Success") or "Failed"
end

function BanManager.GetBanHistoryAsync(UserId: number)
	local success, result: BanHistoryPages = RepeatPcall(Players.GetBanHistoryAsync, Players, UserId)
	local data = {}
	
	if result then
		while true do
			local page = result:GetCurrentPage()
			for _, entry in ipairs(page) do
				table.insert(data, entry)
			end
			if result.IsFinished then
				break
			end
			result:AdvanceToNextPageAsync()
		end
	end
	
	return (success and "Success") or "Failed", data
end

return BanManager