--!strict
-- Funções utilitárias para encontrar/criar instâncias SEM esperar para sempre.

local InstanceUtil = {}

local DEFAULT_TIMEOUT = 10

-- Igual a WaitForChild, mas gera um erro claro se o objeto não aparecer a tempo.
function InstanceUtil.waitForChild(parent: Instance, childName: string, timeout: number?): Instance
	local limit = timeout or DEFAULT_TIMEOUT
	local child = parent:WaitForChild(childName, limit)
	if not child then
		error(
			`[NightShift] Objeto não encontrado: {parent:GetFullName()}.{childName} (esperei {limit}s). `
				.. "Verifique se o nome está correto e se o objeto existe no Explorer.",
			2
		)
	end
	return child
end

-- Busca um caminho como "Shared/Config/GameConfig" a partir de um objeto.
function InstanceUtil.waitForPath(root: Instance, path: string, timeout: number?): Instance
	local current = root
	for _, childName in string.split(path, "/") do
		current = InstanceUtil.waitForChild(current, childName, timeout)
	end
	return current
end

-- Retorna o filho com esse nome e classe, criando-o se não existir.
function InstanceUtil.getOrCreate(parent: Instance, className: string, childName: string): Instance
	local existing = parent:FindFirstChild(childName)
	if existing then
		if not existing:IsA(className) then
			error(
				`[NightShift] {existing:GetFullName()} deveria ser {className}, mas é {existing.ClassName}.`,
				2
			)
		end
		return existing
	end
	local created = Instance.new(className)
	created.Name = childName
	created.Parent = parent
	return created
end

return InstanceUtil
