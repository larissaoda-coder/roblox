--!strict
-- Algo parece se mexer dentro do estoque — quando não há ninguém lá.

local StockroomNoise = {}

local function anchor(ctx: any): BasePart?
	local anchors = ctx.Map:FindFirstChild("EventAnchors")
	local part = anchors and anchors:FindFirstChild("StockroomNoise")
	return if part and part:IsA("BasePart") then part else nil
end

function StockroomNoise.CanRun(ctx: any): boolean
	if not anchor(ctx) then
		return false
	end
	for _, player in ctx.Players do
		local position = ctx.Services.Map:GetCharacterPosition(player)
		if position and ctx.Services.Map:GetZoneAt(position) == "Stockroom" then
			return false
		end
	end
	return true
end

function StockroomNoise.Run(ctx: any)
	local part = anchor(ctx) :: BasePart
	ctx.Services.Audio:PlayAt("StockroomNoise", part.Position)
	task.wait(ctx.Rng:Number(1.5, 3))
	ctx.Services.Audio:PlayAt("StockroomNoise", part.Position, { PlaybackSpeed = 0.85 })
	ctx.WitnessNear(part.Position, 45)
end

return StockroomNoise
