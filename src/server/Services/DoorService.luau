--!strict
-- Portas. Uma porta é uma Part (a folha da porta) com:
--   Tag "Interactable", InteractionType = "Door"
--   Atributos opcionais: Open (boolean), Locked (boolean), Hinge ("Left" | "Right")
-- Outros sistemas (eventos, entidade, NPCs) abrem/fecham/trancam portas por esta API.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local InteractionService = require(script.Parent.InteractionService)

local OPEN_ANGLE = math.rad(95)
local NORMAL_SECONDS = 0.45
local SLAM_SECONDS = 0.12

local log = Log.new("DoorService")

local DoorService = {}

-- (door, isOpen, cause) cause = "Player" | "Event" | "Entity" | "NPC"…  (o áudio usará isto na Fase 9)
DoorService.DoorChanged = Signal.new()

local closedPoses: { [BasePart]: CFrame } = {}

local function getClosedPose(door: BasePart): CFrame
	local pose = closedPoses[door]
	if not pose then
		-- Se a porta já começa aberta no Studio, a pose "fechada" é a atual (ajuste o mapa para começar fechada).
		pose = door.CFrame
		closedPoses[door] = pose
	end
	return pose
end

local function openPose(door: BasePart): CFrame
	local closed = getClosedPose(door)
	local halfWidth = door.Size.X / 2
	local side = if door:GetAttribute("Hinge") == "Right" then 1 else -1
	-- Gira em torno da borda da porta (dobradiça), não do centro.
	return closed
		* CFrame.new(side * halfWidth, 0, 0)
		* CFrame.Angles(0, side * -OPEN_ANGLE, 0)
		* CFrame.new(-side * halfWidth, 0, 0)
end

function DoorService:IsOpen(door: BasePart): boolean
	return door:GetAttribute("Open") == true
end

function DoorService:IsLocked(door: BasePart): boolean
	return door:GetAttribute("Locked") == true
end

function DoorService:SetOpen(door: BasePart, open: boolean, cause: string?, slam: boolean?)
	if self:IsOpen(door) == open then
		return
	end
	getClosedPose(door)
	door:SetAttribute("Open", open)
	local target = if open then openPose(door) else getClosedPose(door)
	local duration = if slam then SLAM_SECONDS else NORMAL_SECONDS
	TweenService:Create(
		door,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = target }
	):Play()
	InteractionService:SetPromptKey(door, if open then "PROMPT_CLOSE_DOOR" else "PROMPT_OPEN_DOOR")
	log:Debug("Porta %s %s (%s)", door.Name, if open then "aberta" else "fechada", cause or "?")
	DoorService.DoorChanged:Fire(door, open, cause or "Unknown", slam == true)
end

function DoorService:Toggle(door: BasePart, cause: string?)
	self:SetOpen(door, not self:IsOpen(door), cause)
end

function DoorService:SetLocked(door: BasePart, locked: boolean)
	door:SetAttribute("Locked", locked)
end

function DoorService:Init()
	InteractionService:RegisterHandler("Door", {
		CanInteract = function(_player: Player, target: Instance)
			if not target:IsA("BasePart") then
				return false, nil
			end
			if DoorService:IsLocked(target) then
				return false, "NOTIFY_DOOR_LOCKED"
			end
			return true, nil
		end,
		OnInteract = function(_player: Player, target: Instance)
			DoorService:Toggle(target :: BasePart, "Player")
		end,
	})
end

return DoorService
