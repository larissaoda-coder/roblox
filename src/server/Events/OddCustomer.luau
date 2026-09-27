--!strict
-- Um cliente chega em horário estranho… e só pergunta que horas são.

local OddCustomer = {}

function OddCustomer.CanRun(ctx: any): boolean
	return not ctx.Services.NPCs:HasActive("Strange")
end

function OddCustomer.Run(ctx: any)
	if ctx.Services.NPCs:Spawn("Strange") then
		ctx.WitnessZone("Store")
	end
end

return OddCustomer
