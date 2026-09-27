--!strict
-- O telefone toca sem ninguém ter ligado. Quem atende ouve uma de várias ligações.

local PhoneRing = {}

local LINES = { "PHONE_LINE_WRONG_NUMBER", "PHONE_LINE_MANAGER", "PHONE_LINE_SILENCE", "PHONE_LINE_COUNT" }

function PhoneRing.CanRun(ctx: any): boolean
	return not ctx.Services.Events:IsPhoneRinging()
end

function PhoneRing.Run(ctx: any)
	local lineKey = ctx.Rng:Pick(LINES) :: string
	local started = ctx.Services.Events:StartPhoneCall({
		LineKey = lineKey,
		RingSeconds = 20,
		OnAnswer = function(player: Player)
			ctx.Witness({ player })
		end,
	})
	if started then
		local anchors = ctx.Map:FindFirstChild("EventAnchors")
		local spot = anchors and anchors:FindFirstChild("PhoneSpot")
		if spot and spot:IsA("BasePart") then
			ctx.WitnessNear(spot.Position, 45)
		end
	end
end

return PhoneRing
