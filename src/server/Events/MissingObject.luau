--!strict
-- Um objeto necessário para uma tarefa desaparece por um tempo… e depois volta.

local MissingObject = {}

function MissingObject.CanRun(ctx: any): boolean
	for _, point in ctx.Services.Tasks:GetAvailablePoints() do
		if point.Instance:IsA("BasePart") and point.Instance.Transparency < 1 then
			return true
		end
	end
	return false
end

function MissingObject.Run(ctx: any)
	local visible = {}
	for _, point in ctx.Services.Tasks:GetAvailablePoints() do
		if point.Instance:IsA("BasePart") and point.Instance.Transparency < 1 then
			table.insert(visible, point)
		end
	end
	local chosen = ctx.Rng:Pick(visible)
	if not chosen then
		return
	end
	local part = chosen.Instance :: BasePart
	local originalTransparency = part.Transparency
	part.Transparency = 1
	ctx.Services.Tasks:SetPointBlocked(chosen.TaskId, chosen.Point, true)
	ctx.WitnessNear(part.Position, 50)

	task.wait(ctx.Rng:Number(40, 70))
	if ctx.IsActive() then
		part.Transparency = originalTransparency
		ctx.Services.Tasks:SetPointBlocked(chosen.TaskId, chosen.Point, false)
	end
end

return MissingObject
