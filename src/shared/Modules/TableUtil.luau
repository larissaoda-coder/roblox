--!strict
-- Funções para copiar e completar tabelas de dados.

local TableUtil = {}

-- Cópia profunda (tabelas dentro de tabelas também são copiadas).
function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: any do
		copy[TableUtil.deepCopy(key)] = TableUtil.deepCopy(item)
	end
	return copy :: any
end

-- Adiciona em `target` as chaves do `template` que estão faltando (recursivamente).
-- Não altera valores já existentes. Usado para atualizar perfis antigos quando o template ganha campos novos.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, templateValue in template do
		local current = target[key]
		if current == nil then
			target[key] = TableUtil.deepCopy(templateValue)
		elseif type(templateValue) == "table" and type(current) == "table" and next(templateValue) ~= nil then
			-- Só completa sub-tabelas "de campos" (template não vazio). Listas vazias (ex.: Owned) ficam como estão.
			TableUtil.reconcile(current, templateValue)
		end
	end
	return target
end

-- Congela a tabela e todas as sub-tabelas.
function TableUtil.deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, item in value :: any do
			TableUtil.deepFreeze(item)
		end
		table.freeze(value :: any)
	end
	return value
end

return TableUtil
