--!strict
-- As luzes da zona onde alguém está começam a piscar.

local LightsFlicker = {}

function LightsFlicker.Run(ctx: any)
	local map = ctx.Services.Map
	local lighting = ctx.Services.Lighting
	local zone = "Store"
	local target = ctx.Rng:Pick(ctx.Players)
	local position = target and map:GetCharacterPosition(target)
	if position then
		local playerZone = map:GetZoneAt(position)
		if lighting:GetZoneState(playerZone) ~= nil then
			zone = playerZone
		end
	end
	lighting:Flicker(zone, ctx.Rng:Number(2, 5))
	local zonePart = map:GetZonePart(zone)
	if zonePart then
		ctx.Services.Audio:PlayAt("LightBuzz", zonePart.Position)
	end
	ctx.WitnessZone(zone)
end

return LightsFlicker
