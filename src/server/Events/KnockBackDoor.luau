--!strict
-- 04:17 — alguém bate na porta dos fundos. Três vezes.

local KnockBackDoor = {}

local function backDoor(ctx: any): BasePart?
	local doors = ctx.Map:FindFirstChild("Doors")
	local door = doors and doors:FindFirstChild("BackDoor")
	return if door and door:IsA("BasePart") then door else nil
end

function KnockBackDoor.CanRun(ctx: any): boolean
	return backDoor(ctx) ~= nil
end

function KnockBackDoor.Run(ctx: any)
	local door = backDoor(ctx) :: BasePart
	for _ = 1, 3 do
		ctx.Services.Audio:PlayAt("Knock", door.Position)
		task.wait(0.9)
	end
	ctx.WitnessNear(door.Position, 60)
end

return KnockBackDoor
