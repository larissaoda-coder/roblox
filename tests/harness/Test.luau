--!nocheck
-- Mini framework de testes: test(nome, fn), expect helpers e waitFor.

local task = require("@lune/task")

local Mock = require("./Mock")

local Test = {}

local registered = {}

function Test.test(name, fn)
	table.insert(registered, { name = name, fn = fn })
end

function Test.fail(message)
	error(message, 2)
end

function Test.expect(condition, message)
	if not condition then
		error(message or "expectativa falhou", 2)
	end
end

function Test.expectEqual(actual, expected, label)
	if actual ~= expected then
		error(`{label or "valor"}: esperado {tostring(expected)}, recebido {tostring(actual)}`, 2)
	end
end

-- Espera uma condição ficar verdadeira (em tempo real) ou falha.
function Test.waitFor(condition, timeout, description)
	local limit = timeout or 3
	local startedAt = os.clock()
	while os.clock() - startedAt < limit do
		local ok, result = pcall(condition)
		if ok and result then
			return result
		end
		task.wait(0.02)
	end
	error(`tempo esgotado esperando: {description or "condição"}`, 2)
end

function Test.findLog(world, pattern, level)
	for _, entry in world.Logs do
		if (level == nil or entry.Level == level) and string.find(entry.Text, pattern) then
			return entry
		end
	end
	return nil
end

function Test.countLogs(world, pattern)
	local count = 0
	for _, entry in world.Logs do
		if string.find(entry.Text, pattern) then
			count += 1
		end
	end
	return count
end

function Test.expectLog(world, pattern, timeout)
	return Test.waitFor(function()
		return Test.findLog(world, pattern)
	end, timeout, `log "{pattern}" em {world.Name}`)
end

function Test.expectNoErrors(world)
	for _, entry in world.Logs do
		if entry.Level == "error" or string.find(entry.Text, "%(ERRO%)") then
			error(`erro inesperado em {world.Name}: {entry.Text}`, 2)
		end
	end
end

function Test.dumpLogs(world)
	for _, entry in world.Logs do
		print(`    [{world.Name}][{entry.Level}] {entry.Text}`)
	end
end

function Test.run(filter)
	local passed, failed = 0, 0
	for _, entry in registered do
		if filter == nil or string.find(entry.name, filter, 1, true) then
			local context = { sessions = {} }
			table.clear(Mock.uncaughtErrors)
			local ok, err = xpcall(entry.fn, debug.traceback, context)
			if ok and #Mock.uncaughtErrors > 0 then
				ok = false
				err = "erro não tratado dentro de um evento:\n" .. Mock.uncaughtErrors[1]
			end
			for _, session in context.sessions do
				session:stop()
			end
			if ok then
				passed += 1
				print(`  ✔ {entry.name}`)
			else
				failed += 1
				print(`  ✘ {entry.name}\n      {string.gsub(tostring(err), "\n", "\n      ")}`)
				for _, session in context.sessions do
					Test.dumpLogs(session.Server)
					for _, client in session.Clients do
						Test.dumpLogs(client)
					end
				end
			end
		end
	end
	print(`\n{passed} passaram, {failed} falharam`)
	return failed == 0
end

return Test
