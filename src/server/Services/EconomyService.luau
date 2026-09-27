--!strict
-- CASH (moeda do jogo) e NIGHT TOKENS (moeda premium). Só o servidor concede ou gasta.
-- Não existe nenhum Remote que peça dinheiro: o cliente só pede AÇÕES (ex.: comprar item X),
-- e o servidor decide o preço.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)

export type Currency = "Cash" | "NightTokens"

local log = Log.new("EconomyService")

local EconomyService = {}

-- (player, currency, delta, reason)
EconomyService.BalanceChanged = Signal.new()

local function validAmount(amount: number): boolean
	return type(amount) == "number"
		and amount == amount
		and amount > 0
		and amount <= EconomyConfig.MAX_GRANT
		and amount % 1 == 0
end

function EconomyService:GetBalance(player: Player, currency: Currency): number
	return DataService:Get(player, currency) or 0
end

function EconomyService:Grant(player: Player, currency: Currency, amount: number, reason: string): boolean
	if not validAmount(amount) then
		log:Error("Concessão inválida para %s: %s %s (%s)", player.Name, tostring(amount), currency, reason)
		return false
	end
	if DataService:Increment(player, currency, amount) == nil then
		return false
	end
	if currency == "Cash" then
		DataService:IncrementStat(player, "CashEarned", amount)
	end
	log:Debug("%s +%d %s (%s)", player.Name, amount, currency, reason)
	EconomyService.BalanceChanged:Fire(player, currency, amount, reason)
	return true
end

-- Retorna false (sem gastar nada) se o saldo não for suficiente.
function EconomyService:Spend(player: Player, currency: Currency, amount: number, reason: string): boolean
	if not validAmount(amount) then
		return false
	end
	if self:GetBalance(player, currency) < amount then
		return false
	end
	if DataService:Increment(player, currency, -amount) == nil then
		return false
	end
	log:Debug("%s -%d %s (%s)", player.Name, amount, currency, reason)
	EconomyService.BalanceChanged:Fire(player, currency, -amount, reason)
	return true
end

function EconomyService:Init() end

return EconomyService
