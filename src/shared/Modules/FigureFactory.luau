--!strict
-- Monta a silhueta usada em aparições (câmeras, percepções, entidade).
-- É feita só de Parts simples (leve para celular) e não colide com nada.

export type FigureOptions = {
	Scale: number?,
	Color: Color3?,
	Eyes: boolean?,
	Name: string?,
}

local DEFAULT_COLOR = Color3.fromRGB(8, 8, 10)

local FigureFactory = {}

local function limb(
	model: Model,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	rootPosition: Vector3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Position = rootPosition + offset
	part.Parent = model
	return part
end

-- Cria a figura de pé, com os pés em `position` (olhando para -Z; use PivotTo para girar).
function FigureFactory.build(position: Vector3, options: FigureOptions?): Model
	local settings: FigureOptions = options or {}
	local scale = settings.Scale or 1
	local color = settings.Color or DEFAULT_COLOR
	local model = Instance.new("Model")
	model.Name = settings.Name or "Figure"

	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * scale, y * scale, z * scale)
	end

	local root = limb(model, "Root", v(2, 2, 1), v(0, 4.4, 0), color, position)
	root.Transparency = 1
	model.PrimaryPart = root
	limb(model, "Torso", v(1.8, 3.2, 0.9), v(0, 5.6, 0), color, position)
	local head = limb(model, "Head", v(1.3, 1.5, 1.3), v(0, 8, 0), color, position)
	head.Shape = Enum.PartType.Ball
	limb(model, "LeftArm", v(0.5, 4.2, 0.5), v(-1.25, 5.1, 0), color, position)
	limb(model, "RightArm", v(0.5, 4.2, 0.5), v(1.25, 5.1, 0), color, position)
	limb(model, "LeftLeg", v(0.7, 4, 0.7), v(-0.45, 2, 0), color, position)
	limb(model, "RightLeg", v(0.7, 4, 0.7), v(0.45, 2, 0), color, position)

	if settings.Eyes then
		for side = -1, 1, 2 do
			local eye = limb(
				model,
				"Eye",
				v(0.12, 0.08, 0.05),
				v(side * 0.28, 8.1, -0.66),
				Color3.fromRGB(200, 200, 190),
				position
			)
			eye.Material = Enum.Material.Neon
			eye.Transparency = 0.4
		end
	end
	return model
end

return FigureFactory
