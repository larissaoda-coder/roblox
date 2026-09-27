--!nocheck
-- Gera os mapas feitos por código como arquivos .rbxm (para aparecerem no Studio em ServerStorage > Maps).
-- Uso (na raiz do repositório): lune run scripts/export-maps.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

-- O Lune não tem a classe Random do Roblox; usamos a versão determinística do simulador de testes.
local Mock = require("../tests/harness/Mock")

local MAPS = {
	GasStation = "src/server/World/GasStationBuilder.luau",
}

local collectionService = {
	AddTag = function(_, instance, tag)
		instance:AddTag(tag)
	end,
}

local env = setmetatable({
	game = {
		GetService = function(_, name)
			assert(name == "CollectionService", `serviço não suportado na exportação: {name}`)
			return collectionService
		end,
	},
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Enum = roblox.Enum,
	Font = roblox.Font,
	Random = Mock.Random,
}, { __index = _G })

fs.writeDir("build")
for mapId, path in MAPS do
	local builder = luau.load(fs.readFile(path), { debugName = path, environment = env })()
	local map = builder.build(mapId)
	fs.writeFile(`build/{mapId}.rbxm`, roblox.serializeModel({ map }))
	print(`build/{mapId}.rbxm gerado ({#map:GetDescendants()} objetos)`)
end
