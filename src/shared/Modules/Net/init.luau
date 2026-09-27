--!strict
-- Camada ÚNICA de comunicação servidor ↔ cliente.
--   Servidor: Net.Server.on / Net.Server.handle / Net.Server.fire / Net.Server.fireAll
--   Cliente:  Net.Client.fire / Net.Client.invoke / Net.Client.on

local RunService = game:GetService("RunService")

local Net = {}

Net.T = require(script.T)

if RunService:IsServer() then
	Net.Server = require(script.Server)
else
	Net.Client = require(script.Client)
end

return Net
