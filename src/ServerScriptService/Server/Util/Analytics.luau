--!strict
-- Thin wrapper around Roblox AnalyticsService (Creator Dashboard → Analytics). Every call is
-- pcall-guarded so analytics can never break gameplay. Only gameplay events, no personal data.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Onboarding funnel: each step is logged once per player, in this order.
Analytics.Onboarding = {
	Joined = 1,
	FirstRelic = 2,
	FirstDisplay = 3,
	FirstUpgrade = 4,
	ForestVisited = 5,
	TutorialDone = 6,
}
local STEP_NAMES = { "Joined", "FirstRelic", "FirstDisplay", "FirstUpgrade", "ForestVisited", "TutorialDone" }

function Analytics.onboarding(player: Player, step: number)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, STEP_NAMES[step])
	end)
end

-- flow: "source" (coins gained) or "sink" (coins spent); sku names the item or reason.
function Analytics.coins(player: Player, flow: string, amount: number, balance: number, sku: string, isPurchase: boolean?)
	pcall(function()
		local flowType = if flow == "sink" then Enum.AnalyticsEconomyFlowType.Sink else Enum.AnalyticsEconomyFlowType.Source
		local transaction = if isPurchase
			then Enum.AnalyticsEconomyTransactionType.IAP.Name
			elseif flow == "sink" then Enum.AnalyticsEconomyTransactionType.Shop.Name
			else Enum.AnalyticsEconomyTransactionType.Gameplay.Name
		AnalyticsService:LogEconomyEvent(player, flowType, "Coins", math.floor(amount), math.floor(balance), transaction, sku)
	end)
end

function Analytics.custom(player: Player, name: string, value: number?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

return Analytics
