--!strict
-- Monitor de câmeras de segurança (escritório).
-- O servidor sabe quem está assistindo qual câmera: eventos podem aparecer SÓ nas câmeras,
-- e apenas quem está olhando aquela câmera testemunha.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)

type CameraInfo = { Id: string, LabelKey: string, CFrame: CFrame, Order: number }
type Viewer = { Index: number, Monitor: BasePart }
type Anomaly = { Type: string, Data: any, EndsAt: number, OnWitness: ((Player) -> ())? }

local MAX_MONITOR_DISTANCE = 14
local CHECK_SECONDS = 1

local log = Log.new("SecurityCameraService")

local SecurityCameraService = {}

-- (player, cameraId) alguém trocou de câmera.
SecurityCameraService.ViewChanged = Signal.new()

local cameras: { CameraInfo } = {}
local viewers: { [Player]: Viewer } = {}
local anomalies: { [string]: Anomaly } = {}

local function loadCameras()
	table.clear(cameras)
	local folder = MapService:GetFolder("SecurityCameras")
	if not folder then
		return
	end
	for _, camera in folder:GetChildren() do
		if camera:IsA("BasePart") then
			table.insert(cameras, {
				Id = tostring(camera:GetAttribute("CameraId") or camera.Name),
				LabelKey = tostring(camera:GetAttribute("LabelKey") or camera.Name),
				CFrame = camera.CFrame,
				Order = tonumber(camera:GetAttribute("Order")) or 99,
			})
		end
	end
	table.sort(cameras, function(a, b)
		return a.Order < b.Order
	end)
end

local function sendAnomalyIfAny(player: Player, cameraId: string)
	local anomaly = anomalies[cameraId]
	if anomaly and os.clock() < anomaly.EndsAt then
		Net.Server.fire(
			"CameraAnomaly",
			player,
			cameraId,
			anomaly.Type,
			anomaly.Data,
			anomaly.EndsAt - os.clock()
		)
		if anomaly.OnWitness then
			anomaly.OnWitness(player)
		end
	end
end

local function close(player: Player, notifyClient: boolean)
	if not viewers[player] then
		return
	end
	viewers[player] = nil
	player:SetAttribute("ViewingCamera", nil)
	if notifyClient then
		Net.Server.fire("CameraFeedClosed", player)
	end
end

local function setView(player: Player, index: number)
	local viewer = viewers[player]
	local camera = cameras[index]
	if not viewer or not camera then
		return
	end
	viewer.Index = index
	player:SetAttribute("ViewingCamera", camera.Id)
	SecurityCameraService.ViewChanged:Fire(player, camera.Id)
	sendAnomalyIfAny(player, camera.Id)
end

local function isNearMonitor(player: Player, monitor: BasePart): boolean
	local position = MapService:GetCharacterPosition(player)
	return position ~= nil and (position - monitor.Position).Magnitude <= MAX_MONITOR_DISTANCE
end

-- API ---------------------------------------------------------------------------------

function SecurityCameraService:GetCameras(): { CameraInfo }
	return cameras
end

function SecurityCameraService:GetViewers(cameraId: string?): { Player }
	local list = {}
	for player, viewer in viewers do
		local camera = cameras[viewer.Index]
		if cameraId == nil or (camera and camera.Id == cameraId) then
			table.insert(list, player)
		end
	end
	return list
end

function SecurityCameraService:GetCameraCFrame(cameraId: string): CFrame?
	for _, camera in cameras do
		if camera.Id == cameraId then
			return camera.CFrame
		end
	end
	return nil
end

-- Mostra algo SÓ na câmera `cameraId` por `duration` segundos.
-- `onWitness(player)` é chamado para cada jogador que vê (agora ou trocando para essa câmera depois).
function SecurityCameraService:ShowAnomaly(
	cameraId: string,
	anomalyType: string,
	data: any,
	duration: number,
	onWitness: ((Player) -> ())?
)
	anomalies[cameraId] =
		{ Type = anomalyType, Data = data, EndsAt = os.clock() + duration, OnWitness = onWitness }
	for _, player in self:GetViewers(cameraId) do
		sendAnomalyIfAny(player, cameraId)
	end
	log:Debug("Anomalia %s na %s por %.0fs", anomalyType, cameraId, duration)
end

function SecurityCameraService:Init()
	InteractionService:RegisterHandler("SecurityMonitor", {
		CanInteract = function(player: Player)
			return MatchService:IsPlayerInMatch(player) and #cameras > 0, nil
		end,
		OnInteract = function(player: Player, target: Instance)
			viewers[player] = { Index = 1, Monitor = target :: BasePart }
			local payload = {}
			for _, camera in cameras do
				table.insert(payload, { Id = camera.Id, LabelKey = camera.LabelKey, CFrame = camera.CFrame })
			end
			Net.Server.fire("CameraFeedOpened", player, payload)
			setView(player, 1)
		end,
	})

	Net.Server.on("SetCameraView", function(player: Player, index: number)
		local viewer = viewers[player]
		if viewer and isNearMonitor(player, viewer.Monitor) then
			setView(player, index)
		end
	end)
	Net.Server.on("CloseCameraFeed", function(player: Player)
		close(player, false)
	end)
end

function SecurityCameraService:Start()
	MatchService.MatchStarted:Connect(function()
		table.clear(viewers)
		table.clear(anomalies)
		loadCameras()
	end)
	MatchService.MatchEnded:Connect(function()
		for player in viewers do
			close(player, true)
		end
		table.clear(anomalies)
	end)

	-- Quem se afasta do monitor sai das câmeras.
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for player, viewer in viewers do
				if player.Parent == nil then
					viewers[player] = nil
				elseif not isNearMonitor(player, viewer.Monitor) then
					close(player, true)
				end
			end
		end
	end)
end

return SecurityCameraService
