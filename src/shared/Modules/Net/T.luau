--!strict
-- Validadores de argumentos para Remotes. Cada validador retorna (ok, motivo).
-- Usados pelo RemoteSchema. O servidor rejeita qualquer chamada que não passe.

export type Validator = (value: any) -> (boolean, string?)

local DEFAULT_MAX_STRING = 100

local T = {}

function T.string(maxLength: number?): Validator
	local limit = maxLength or DEFAULT_MAX_STRING
	return function(value)
		if type(value) ~= "string" then
			return false, "esperava string"
		end
		if #value > limit then
			return false, "string muito longa"
		end
		return true
	end
end

-- Rejeita NaN e infinito, que exploiters usam para quebrar cálculos.
function T.number(min: number?, max: number?): Validator
	return function(value)
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return false, "esperava número"
		end
		if (min and value < min) or (max and value > max) then
			return false, "número fora do intervalo"
		end
		return true
	end
end

function T.integer(min: number?, max: number?): Validator
	local checkNumber = T.number(min, max)
	return function(value)
		local ok, reason = checkNumber(value)
		if not ok then
			return false, reason
		end
		if value % 1 ~= 0 then
			return false, "esperava número inteiro"
		end
		return true
	end
end

function T.boolean(): Validator
	return function(value)
		if type(value) ~= "boolean" then
			return false, "esperava boolean"
		end
		return true
	end
end

-- Aceita uma Instance da classe indicada. ATENÇÃO: o serviço ainda precisa validar
-- se a instância é a esperada (ex.: pertence ao mapa ativo, está perto do jogador).
function T.instance(className: string?): Validator
	return function(value)
		if typeof(value) ~= "Instance" then
			return false, "esperava Instance"
		end
		if className and not value:IsA(className) then
			return false, `esperava {className}`
		end
		return true
	end
end

function T.oneOf(options: { any }): Validator
	return function(value)
		if table.find(options, value) == nil then
			return false, "valor não permitido"
		end
		return true
	end
end

-- Aceita qualquer um dos tipos primitivos listados (números ainda rejeitam NaN/infinito).
function T.oneOfTypes(types: { string }): Validator
	local checkNumber = T.number()
	return function(value)
		local valueType = type(value)
		if not table.find(types, valueType) then
			return false, "tipo não permitido"
		end
		if valueType == "number" then
			return checkNumber(value)
		end
		return true
	end
end

function T.optional(validator: Validator): Validator
	return function(value)
		if value == nil then
			return true
		end
		return validator(value)
	end
end

return T
