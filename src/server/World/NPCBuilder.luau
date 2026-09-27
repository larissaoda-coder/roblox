--!strict
-- Monta o modelo de um cliente: bloco simples de Parts ancoradas (sem física, leve).
-- A Part "Root" recebe o prompt de conversa (tag Interactable, InteractionType = "NPC").

local CollectionService = game:GetService("CollectionService")

local NPCBuilder = {}

export type Colors = { Skin: Color3, Shirt: Color3, Pants: Color3 }

local function part(
	model: Model,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	base: Vector3
): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.CanTouch = false
	newPart.Size = size
	newPart.Color = color
	newPart.Material = Enum.Material.SmoothPlastic
	newPart.Position = base + offset
	newPart.Parent = model
	return newPart
end

function NPCBuilder.build(npcId: string, colors: Colors, height: number, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = `NPC_{npcId}`
	local scale = height
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * scale, y * scale, z * scale)
	end
	local root = part(model, "Root", v(2, 2, 1), v(0, 3, 0), colors.Shirt, position)
	root.Transparency = 1
	root.CanQuery = true
	model.PrimaryPart = root
	part(model, "Torso", v(2, 2, 1), v(0, 3, 0), colors.Shirt, position)
	part(model, "Head", v(1.2, 1.2, 1.2), v(0, 4.6, 0), colors.Skin, position)
	part(model, "LeftArm", v(1, 2, 1), v(-1.5, 3, 0), colors.Shirt, position)
	part(model, "RightArm", v(1, 2, 1), v(1.5, 3, 0), colors.Shirt, position)
	part(model, "LeftLeg", v(1, 2, 1), v(-0.5, 1, 0), colors.Pants, position)
	part(model, "RightLeg", v(1, 2, 1), v(0.5, 1, 0), colors.Pants, position)

	root:SetAttribute("InteractionType", "NPC")
	root:SetAttribute("PromptKey", "PROMPT_TALK")
	root:SetAttribute("MaxDistance", 9)
	root:SetAttribute("Enabled", false)
	root:SetAttribute("NPCId", npcId)
	CollectionService:AddTag(root, "Interactable")
	return model
end

return NPCBuilder
