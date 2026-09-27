--!strict
-- ÚNICA porta de leitura/escrita dos dados salvos dos jogadores.
-- Outros serviços NUNCA alteram tabelas de dados diretamente: usam Set / Update / Increment / IncrementStat.
--
-- Fase 2: armazenamento em memória. Fase 13: DataStore real, com a MESMA API.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)
local TableUtil = require(Shared.Modules.TableUtil)

local Server = script.Parent.Parent
local DataConfig = require(Server.ServerDefinitions.DataConfig)
local MemoryBackend = require(Server.Data.MemoryBackend)

type Data = { [string]: any }

type Profile = {
	Data: Data,
}

local log = Log.new("DataService")

local DataService = {}

-- (player, data) quando o perfil termina de carregar.
DataService.ProfileLoaded = Signal.new()
-- (player, key, newValue, oldValue) sempre que um campo muda.
DataService.Changed = Signal.new()

local backend = MemoryBackend
local profiles: { [Player]: Profile } = {}
local loading: { [Player]: boolean } = {}

local function isValidNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function applyAttribute(player: Player, key: string, value: any)
	if table.find(DataConfig.PUBLIC_ATTRIBUTES, key) then
		player:SetAttribute(key, value)
	end
end

local function saveProfile(player: Player, profile: Profile): boolean
	local ok, err = backend:Save(player.UserId, profile.Data)
	if not ok then
		log:Error("Falha ao salvar dados de %s: %s", player.Name, tostring(err))
	end
	return ok
end

local function commit(player: Player, profile: Profile, key: string, newValue: any)
	local oldValue = profile.Data[key]
	profile.Data[key] = newValue
	applyAttribute(player, key, newValue)
	DataService.Changed:Fire(player, key, TableUtil.deepCopy(newValue), oldValue)
end

-- Garante que o campo existe no template e que o tipo do novo valor bate com o do template.
local function checkValue(key: string, value: any): (boolean, string?)
	local templateValue = DataConfig.TEMPLATE[key]
	if templateValue == nil then
		return false, `campo "{key}" não existe no DataConfig.TEMPLATE`
	end
	if type(value) ~= type(templateValue) then
		return false, `campo "{key}" deveria ser {type(templateValue)}, recebeu {type(value)}`
	end
	if type(value) == "number" and not isValidNumber(value) then
		return false, `campo "{key}" recebeu número inválido`
	end
	return true, nil
end

function DataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Carrega o perfil. Retorna true se carregou (ou já estava carregado).
function DataService:LoadProfile(player: Player): boolean
	if profiles[player] then
		return true
	end
	if loading[player] then
		while loading[player] do
			task.wait()
		end
		return profiles[player] ~= nil
	end

	loading[player] = true
	local ok, stored = backend:Load(player.UserId)
	loading[player] = nil

	if not ok then
		log:Error("Falha ao carregar dados de %s: %s", player.Name, tostring(stored))
		return false
	end
	if player.Parent == nil then
		log:Debug("%s saiu antes de terminar de carregar. Nada foi salvo.", player.Name)
		return false
	end

	local isNew = stored == nil
	local data: Data = if isNew then TableUtil.deepCopy(DataConfig.TEMPLATE) :: any else stored
	TableUtil.reconcile(data, DataConfig.TEMPLATE)
	data.SchemaVersion = DataConfig.SCHEMA_VERSION
	if isNew then
		data.FirstJoin = os.time()
	end
	data.LastJoin = os.time()

	profiles[player] = { Data = data }
	for _, key in DataConfig.PUBLIC_ATTRIBUTES do
		player:SetAttribute(key, data[key])
	end

	log:Debug("Perfil de %s carregado (%s)", player.Name, if isNew then "novo" else "existente")
	DataService.ProfileLoaded:Fire(player, TableUtil.deepCopy(data))
	return true
end

-- Salva e remove o perfil da memória do servidor. Chamado quando o jogador sai.
function DataService:ReleaseProfile(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	profiles[player] = nil
	return saveProfile(player, profile)
end

-- Retorna uma CÓPIA do valor (alterar a cópia não altera os dados salvos). nil se não carregado.
function DataService:Get(player: Player, key: string): any
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return TableUtil.deepCopy(profile.Data[key])
end

function DataService:Set(player: Player, key: string, value: any): boolean
	local profile = profiles[player]
	if not profile then
		log:Warn("Set(%s) ignorado: perfil de %s não carregado", key, player.Name)
		return false
	end
	local ok, reason = checkValue(key, value)
	if not ok then
		log:Error("Set rejeitado para %s: %s", player.Name, tostring(reason))
		return false
	end
	commit(player, profile, key, TableUtil.deepCopy(value))
	return true
end

-- Atualiza um campo com uma função que recebe uma cópia do valor atual e retorna o novo valor.
-- Ex.: DataService:Update(player, "Titles", function(titles) titles.FirstShift = true return titles end)
function DataService:Update(player: Player, key: string, transform: (current: any) -> any): boolean
	local profile = profiles[player]
	if not profile then
		log:Warn("Update(%s) ignorado: perfil de %s não carregado", key, player.Name)
		return false
	end
	local newValue = transform(TableUtil.deepCopy(profile.Data[key]))
	return self:Set(player, key, newValue)
end

-- Soma `delta` a um campo numérico. Retorna o novo valor, ou nil se rejeitado.
function DataService:Increment(player: Player, key: string, delta: number): number?
	local profile = profiles[player]
	if not profile then
		log:Warn("Increment(%s) ignorado: perfil de %s não carregado", key, player.Name)
		return nil
	end
	if not isValidNumber(delta) or type(DataConfig.TEMPLATE[key]) ~= "number" then
		log:Error("Increment rejeitado para %s: campo %s, delta %s", player.Name, key, tostring(delta))
		return nil
	end
	local newValue = profile.Data[key] + delta
	commit(player, profile, key, newValue)
	return newValue
end

-- Soma `delta` a uma estatística (Stats.Deaths, Stats.TasksCompleted…). Retorna o novo valor.
function DataService:IncrementStat(player: Player, statName: string, delta: number): number?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local stats = profile.Data.Stats
	if not isValidNumber(delta) or type(stats[statName]) ~= "number" then
		log:Error("IncrementStat rejeitado para %s: %s, delta %s", player.Name, statName, tostring(delta))
		return nil
	end
	local newStats = TableUtil.deepCopy(stats)
	newStats[statName] += delta
	commit(player, profile, "Stats", newStats)
	return newStats[statName]
end

function DataService:SaveAll()
	for player, profile in profiles do
		task.spawn(saveProfile, player, profile)
	end
end

function DataService:Init()
	if DataConfig.BACKEND ~= "Memory" then
		log:Warn("Backend %s ainda não implementado (Fase 13). Usando memória.", DataConfig.BACKEND)
	end
end

function DataService:Start()
	game:BindToClose(function()
		for player, profile in profiles do
			saveProfile(player, profile)
		end
	end)

	while true do
		task.wait(DataConfig.AUTOSAVE_INTERVAL)
		self:SaveAll()
	end
end

return DataService
