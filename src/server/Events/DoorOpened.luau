--!strict
-- Uma porta que estava fechada aparece aberta — sem barulho. Só percebe quem passa por ela.

local DoorOpened = {}

local MIN_DISTANCE_FROM_PLAYERS = 20

local function candidates(ctx: any): { BasePart }
	local doors = ctx.Map:FindFirstChild("Doors")
	local list = {}
	if not doors then
		return list
	end
	for _, door in doors:GetChildren() do
		if
			door:IsA("BasePart")
			and door:GetAttribute("Open") ~= true
			and door:GetAttribute("Locked") ~= true
		then
			local farFromEveryone = true
			for _, player in ctx.Players do
				local position = ctx.Services.Map:GetCharacterPosition(player)
				if position and (position - door.Position).Magnitude < MIN_DISTANCE_FROM_PLAYERS then
					farFromEveryone = false
				end
			end
			if farFromEveryone then
				table.insert(list, door)
			end
		end
	end
	return list
end

function DoorOpened.CanRun(ctx: any): boolean
	return #candidates(ctx) > 0
end

function DoorOpened.Run(ctx: any)
	local door: BasePart = ctx.Rng:Pick(candidates(ctx))
	ctx.Services.Doors:SetOpen(door, true, "Silent")
	ctx.WitnessNear(door.Position, 35)
end

return DoorOpened
