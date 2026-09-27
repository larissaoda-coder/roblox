--!strict
-- Quem está perto do espelho vê, por um instante, alguém atrás de si. Só essa pessoa vê.

local Reflection = {}

local MIRROR_RADIUS = 12

local function mirror(ctx: any): BasePart?
	local bathroom = ctx.Map:FindFirstChild("Bathroom")
	local part = bathroom and bathroom:FindFirstChild("Mirror")
	return if part and part:IsA("BasePart") then part else nil
end

local function playerNearMirror(ctx: any): Player?
	local part = mirror(ctx)
	if not part then
		return nil
	end
	for _, player in ctx.Players do
		local position = ctx.Services.Map:GetCharacterPosition(player)
		if position and (position - part.Position).Magnitude <= MIRROR_RADIUS then
			return player
		end
	end
	return nil
end

function Reflection.CanRun(ctx: any): boolean
	local target = playerNearMirror(ctx)
	if target then
		ctx.Target = target
	end
	return target ~= nil
end

function Reflection.Run(ctx: any)
	local target = ctx.Target :: Player
	local part = mirror(ctx) :: BasePart
	local position = ctx.Services.Map:GetCharacterPosition(target) :: Vector3
	local away = position - part.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	local behind = position + (if flat.Magnitude > 0.1 then flat.Unit * 3 else Vector3.new(0, 0, 3))
	ctx.Perceive(
		target,
		"Figure",
		{ Position = Vector3.new(behind.X, position.Y - 3, behind.Z), Duration = 0.7 }
	)
	ctx.Perceive(target, "Sound", { Sound = "Whisper", Position = behind })
	ctx.Witness({ target })
end

return Reflection
