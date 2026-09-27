--!strict
-- Passos numa área vazia. SÓ o jogador-alvo (normalmente sozinho) ouve.

local PhantomFootsteps = {}

function PhantomFootsteps.CanRun(ctx: any): boolean
	local target = ctx.Target
	return target ~= nil
		and ctx.Services.Tension:IsAlone(target)
		and ctx.Services.Map:GetCharacterPosition(target) ~= nil
end

function PhantomFootsteps.Run(ctx: any)
	local target = ctx.Target :: Player
	local origin = ctx.Services.Map:GetCharacterPosition(target) :: Vector3
	local angle = ctx.Rng:Number(0, math.pi * 2)
	local distance = ctx.Rng:Number(7, 12)
	local position = origin + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	for _ = 1, 3 do
		ctx.Perceive(target, "Sound", { Sound = "Footsteps", Position = position })
		task.wait(0.6)
		position += Vector3.new(ctx.Rng:Number(-1.5, 1.5), 0, ctx.Rng:Number(-1.5, 1.5))
	end
	ctx.Witness({ target })
end

return PhantomFootsteps
