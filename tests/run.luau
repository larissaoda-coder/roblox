--!nocheck
-- Executa todos os testes: lune run tests/run.luau [filtro]
-- Rode a partir da pasta raiz do repositório.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Test = require("./harness/Test")

local specs = fs.readDir("tests/specs")
table.sort(specs)
for _, fileName in specs do
	local name = string.match(fileName, "^(.+)%.luau$")
	if name then
		require(`./specs/{name}`)
	end
end

local ok = Test.run(process.args[1])
process.exit(if ok then 0 else 1)
