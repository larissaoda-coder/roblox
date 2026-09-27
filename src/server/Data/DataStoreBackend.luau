--!strict
-- Salvamento real com DataStoreService + UpdateAsync e TRAVA DE SESSÃO:
-- o perfil guarda qual servidor (JobId) está usando os dados. Outro servidor não sobrescreve
-- enquanto a trava é recente — isso evita duplicação de itens ao trocar de servidor rápido.
--
-- Formato salvo: { Data = <perfil>, Session = { JobId, Time } | nil }

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Modules.Log)

local STORE_NAME = "NightShift_Players_v1"
local MAX_ATTEMPTS = 4
local LOCK_TIMEOUT_SECONDS = 30 * 60 -- trava velha (servidor caiu) pode ser tomada
local LOCKED_RETRY_SECONDS = 6
local LOCKED_MAX_WAITS = 5

local log = Log.new("DataStoreBackend")

local DataStoreBackend = {}

local store: DataStore? = nil

local function getStore(): DataStore
	if not store then
		store = DataStoreService:GetDataStore(STORE_NAME)
	end
	return store :: DataStore
end

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function jobId(): string
	return if game.JobId ~= "" then game.JobId else "Studio"
end

-- Chama `callback` com novas tentativas e espera crescente (1s, 2s, 4s…).
local function withRetries<T>(label: string, callback: () -> T): (boolean, T | string)
	local lastError = ""
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		log:Warn("%s falhou (tentativa %d/%d): %s", label, attempt, MAX_ATTEMPTS, lastError)
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

-- Testa se o DataStore está acessível (no Studio precisa de "Enable Studio Access to API Services").
function DataStoreBackend:IsAvailable(): boolean
	local ok = pcall(function()
		getStore():GetAsync("__availability_check")
	end)
	return ok
end

-- Retorna (true, dados | nil se novo) ou (false, erro). Espera se outro servidor estiver com a trava.
function DataStoreBackend:Load(userId: number): (boolean, any)
	for _ = 1, LOCKED_MAX_WAITS do
		local lockedByOther = false
		local loaded: any = nil
		local ok, err = withRetries(`Load {userId}`, function()
			getStore():UpdateAsync(keyFor(userId), function(saved)
				local record = if type(saved) == "table" then saved else {}
				local session = record.Session
				if
					type(session) == "table"
					and session.JobId ~= jobId()
					and os.time() - (tonumber(session.Time) or 0) < LOCK_TIMEOUT_SECONDS
				then
					lockedByOther = true
					return nil -- cancela: não mexe nos dados de outro servidor
				end
				record.Session = { JobId = jobId(), Time = os.time() }
				loaded = record.Data
				return record
			end)
			return true
		end)
		if not ok then
			return false, err
		end
		if not lockedByOther then
			return true, loaded
		end
		log:Warn("Perfil %d está em uso em outro servidor. Esperando…", userId)
		task.wait(LOCKED_RETRY_SECONDS)
	end
	return false, "SessionLocked"
end

-- Salva. release = true libera a trava (jogador saiu).
function DataStoreBackend:Save(userId: number, data: any, release: boolean?): (boolean, string?)
	local lostLock = false
	local ok, err = withRetries(`Save {userId}`, function()
		getStore():UpdateAsync(keyFor(userId), function(saved)
			local record = if type(saved) == "table" then saved else {}
			local session = record.Session
			if type(session) == "table" and session.JobId ~= jobId() then
				lostLock = true
				return nil -- outro servidor assumiu: não sobrescrever
			end
			record.Data = data
			record.Session = if release then nil else { JobId = jobId(), Time = os.time() }
			return record
		end)
		return true
	end)
	if not ok then
		return false, tostring(err)
	end
	if lostLock then
		return false, "SessionLost"
	end
	return true, nil
end

return DataStoreBackend
