--!strict
-- Lanterna: igual para todos (alcance e brilho). Só a COR muda com o item equipado.
-- O servidor cria a luz no personagem, então os colegas também veem o feixe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Modules.Net)

local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)

local LIGHT_NAME = "NS_Flashlight"

local FlashlightService = {}

local function getLight(player: Player, create: boolean): SpotLight?
	local character = player.Character
	local anchor = character
		and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not anchor then
		return nil
	end
	local light = anchor:FindFirstChild(LIGHT_NAME) :: SpotLight?
	if not light and create then
		local newLight = Instance.new("SpotLight")
		newLight.Name = LIGHT_NAME
		newLight.Face = Enum.NormalId.Front
		newLight.Range = 45
		newLight.Angle = 50
		newLight.Brightness = 2.5
		newLight.Shadows = true
		newLight.Enabled = false
		newLight.Parent = anchor
		light = newLight
	end
	return light
end

function FlashlightService:IsOn(player: Player): boolean
	return player:GetAttribute("FlashlightOn") == true
end

function FlashlightService:Set(player: Player, on: boolean)
	local allowed = on and MatchService:IsAlive(player)
	local light = getLight(player, allowed)
	if light then
		local skin = InventoryService:GetEquipped(player, "FLASHLIGHTS")
		light.Color = if skin and skin.Data.Color then skin.Data.Color else Color3.new(1, 1, 1)
		light.Enabled = allowed
	end
	player:SetAttribute("FlashlightOn", allowed)
end

function FlashlightService:Init()
	Net.Server.on("SetFlashlight", function(player: Player, on: boolean)
		FlashlightService:Set(player, on)
	end)
end

function FlashlightService:Start()
	MatchService.MatchEnded:Connect(function(_match, result)
		for _, player in result.Players do
			FlashlightService:Set(player, false)
		end
	end)
end

return FlashlightService
