--!strict
-- Todas as luzes se apagam. Só as luzes de emergência ficam acesas.

local Blackout = {}

function Blackout.CanRun(ctx: any): boolean
	return not ctx.Services.Lighting:IsBlackout()
end

function Blackout.Run(ctx: any)
	ctx.Services.Lighting:Blackout(ctx.Rng:Number(14, 24))
	ctx.WitnessAll()
end

return Blackout
