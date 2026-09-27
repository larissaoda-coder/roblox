--!strict
-- Armazenamento em memória: os dados vivem enquanto o servidor estiver aberto.
-- Tem a mesma interface que o DataStoreBackend terá na Fase 13.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Modules.TableUtil)

-- Atraso artificial para simular a rede do DataStore nos testes (0 = sem atraso).
local LATENCY_SECONDS = 0

local store: { [number]: any } = {}

local MemoryBackend = {}

-- Retorna (true, dados | nil se jogador novo) ou (false, mensagem de erro).
function MemoryBackend:Load(userId: number): (boolean, any)
	if LATENCY_SECONDS > 0 then
		task.wait(LATENCY_SECONDS)
	end
	return true, TableUtil.deepCopy(store[userId])
end

function MemoryBackend:IsAvailable(): boolean
	return true
end

function MemoryBackend:Save(userId: number, data: any, _release: boolean?): (boolean, string?)
	if LATENCY_SECONDS > 0 then
		task.wait(LATENCY_SECONDS)
	end
	store[userId] = TableUtil.deepCopy(data)
	return true, nil
end

return MemoryBackend
