--!strict
-- Um cliente entra, fala com você… e não aparece nas câmeras. A descoberta acontece ao falar com ele
-- (ação do diálogo) ou ao olhar as câmeras enquanto ele está no caixa.

local CustomerNoRecord = {}

function CustomerNoRecord.CanRun(ctx: any): boolean
	return not ctx.Services.NPCs:HasActive("NoRecord")
end

function CustomerNoRecord.Run(ctx: any)
	ctx.Services.NPCs:Spawn("NoRecord")
end

return CustomerNoRecord
