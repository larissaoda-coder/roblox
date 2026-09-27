--!strict
-- 04:33 — alguém está parado do outro lado da estrada, olhando para o posto.
-- Some quando alguém chega perto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FigureFactory = require(ReplicatedStorage.Shared.Modules.FigureFactory)

local RoadFigure = {}

local DURATION = 30
local VANISH_DISTANCE = 35

local function anchor(ctx: any): BasePart?
	local anchors = ctx.Map:FindFirstChild("EventAnchors")
	local part = anchors and anchors:FindFirstChild("RoadFigure")
	return if part and part:IsA("BasePart") then part else nil
end

function RoadFigure.CanRun(ctx: any): boolean
	return anchor(ctx) ~= nil
end

function RoadFigure.Run(ctx: any)
	local part = anchor(ctx) :: BasePart
	local figure =
		FigureFactory.build(part.Position - Vector3.new(0, 3, 0), { Name = "RoadFigure", Eyes = true })
	figure.Parent = ctx.Map

	-- Quem está do lado de fora consegue ver.
	local outside = {}
	for _, player in ctx.Players do
		local position = ctx.Services.Map:GetCharacterPosition(player)
		if position then
			local _, zonePart = ctx.Services.Map:GetZoneAt(position)
			if not zonePart or zonePart:GetAttribute("Indoor") ~= true then
				table.insert(outside, player)
			end
		end
	end
	ctx.Witness(outside)

	local startedAt = os.clock()
	while os.clock() - startedAt < DURATION and ctx.IsActive() do
		local someoneClose = false
		for _, player in ctx.Players do
			local position = ctx.Services.Map:GetCharacterPosition(player)
			if position and (position - part.Position).Magnitude < VANISH_DISTANCE then
				someoneClose = true
			end
		end
		if someoneClose then
			break
		end
		task.wait(0.5)
	end
	figure:Destroy()
end

return RoadFigure
