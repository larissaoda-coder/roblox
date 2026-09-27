--!strict
-- Várias portas começam a abrir e bater, uma depois da outra.

local DoorsSlam = {}

function DoorsSlam.CanRun(ctx: any): boolean
	local doors = ctx.Map:FindFirstChild("Doors")
	return doors ~= nil and #doors:GetChildren() >= 2
end

function DoorsSlam.Run(ctx: any)
	local doors = ctx.Rng:Shuffle(ctx.Map.Doors:GetChildren())
	ctx.WitnessAll()
	for index = 1, math.min(3, #doors) do
		local door = doors[index]
		if door:IsA("BasePart") and door:GetAttribute("Locked") ~= true and ctx.IsActive() then
			local doorService = ctx.Services.Doors
			doorService:SetOpen(door, true, "Event", true)
			task.wait(0.35)
			doorService:SetOpen(door, false, "Event", true)
			task.wait(ctx.Rng:Number(0.4, 0.9))
		end
	end
end

return DoorsSlam
