--!strict
-- Carrega os ModuleScripts de uma pasta (Services ou Controllers) e executa o ciclo de vida:
--   1. Init()  de TODOS, em sequência. Não pode esperar (yield) nem chamar outros módulos.
--   2. Start() de TODOS, cada um em sua própria thread. Aqui os módulos já podem conversar.

local Log = require(script.Parent.Log)

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local SLOW_INIT_SECONDS = 1

local log = Log.new("Loader")

local Loader = {}

function Loader.load(folder: Instance): { [string]: Module }
	local modules: { [string]: Module } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if not ok then
				log:Error("Falha ao carregar %s: %s", child:GetFullName(), tostring(result))
			elseif type(result) ~= "table" then
				log:Error("%s precisa retornar uma tabela", child:GetFullName())
			else
				modules[child.Name] = result :: Module
			end
		end
	end
	return modules
end

local function sortedNames(modules: { [string]: Module }): { string }
	local names = {}
	for name in modules do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Loader.init(modules: { [string]: Module })
	for _, name in sortedNames(modules) do
		local module = modules[name]
		local init = module.Init
		if init then
			local startedAt = os.clock()
			local ok, err = xpcall(function()
				init(module)
			end, debug.traceback)
			if not ok then
				log:Error("%s:Init() falhou:\n%s", name, tostring(err))
			end
			local elapsed = os.clock() - startedAt
			if elapsed > SLOW_INIT_SECONDS then
				log:Warn(
					"%s:Init() demorou %.2fs. Init não deve esperar; mova isso para Start().",
					name,
					elapsed
				)
			end
		end
	end
end

function Loader.start(modules: { [string]: Module }): number
	local count = 0
	for _, name in sortedNames(modules) do
		local module = modules[name]
		count += 1
		local start = module.Start
		if start then
			task.spawn(function()
				local ok, err = xpcall(function()
					start(module)
				end, debug.traceback)
				if not ok then
					log:Error("%s:Start() falhou:\n%s", name, tostring(err))
				end
			end)
		end
	end
	return count
end

return Loader
