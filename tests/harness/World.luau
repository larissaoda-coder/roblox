--!nocheck
-- Monta "mundos" (servidor e clientes) a partir de src/, seguindo as mesmas regras do Rojo,
-- e executa os scripts reais do jogo dentro deles.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Mock = require("./Mock")

local BASE_GLOBALS = {
	string = string,
	table = table,
	math = math,
	os = os,
	debug = debug,
	coroutine = coroutine,
	utf8 = utf8,
	bit32 = bit32,
	buffer = buffer,
	select = select,
	type = type,
	tostring = tostring,
	tonumber = tonumber,
	pairs = pairs,
	ipairs = ipairs,
	next = next,
	pcall = pcall,
	xpcall = xpcall,
	error = error,
	assert = assert,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	rawlen = rawlen,
	unpack = table.unpack,
	newproxy = newproxy,
}

local World = {}
World.__index = World

local function sortedEntries(path)
	local entries = fs.readDir(path)
	table.sort(entries)
	return entries
end

-- Converte arquivos/pastas em Instances (regras do Rojo).
function World:build(path, name, patches)
	local function read(filePath)
		local source = fs.readFile(filePath)
		local patch = patches and patches[filePath]
		return if patch then patch(source) else source
	end

	if fs.isDir(path) then
		name = name or string.match(path, "[^/]+$")
		local instance
		local initPath = path .. "/init.luau"
		if fs.isFile(initPath) then
			instance = self.newInstance("ModuleScript", name)
			instance.Source = read(initPath)
		else
			instance = self.newInstance("Folder", name)
		end
		for _, entry in sortedEntries(path) do
			if entry ~= "init.luau" then
				local child = self:build(path .. "/" .. entry, nil, patches)
				if child then
					child.Parent = instance
				end
			end
		end
		return instance
	end

	local fileName = string.match(path, "[^/]+$")
	local className, instanceName
	local baseName = string.match(fileName, "^(.+)%.server%.luau$")
	if baseName then
		className, instanceName = "Script", baseName
	else
		baseName = string.match(fileName, "^(.+)%.client%.luau$")
		if baseName then
			className, instanceName = "LocalScript", baseName
		else
			baseName = string.match(fileName, "^(.+)%.luau$")
			if not baseName then
				return nil
			end
			className, instanceName = "ModuleScript", baseName
		end
	end
	local instance = self.newInstance(className, name or instanceName)
	instance.Source = read(path)
	return instance
end

function World:log(level, ...)
	local parts = table.pack(...)
	for index = 1, parts.n do
		parts[index] = tostring(parts[index])
	end
	local text = table.concat(parts, " ", 1, parts.n)
	table.insert(self.Logs, { Level = level, Text = text })
	if self.Verbose then
		print(`  [{self.Name}] {text}`)
	end
end

function World:makeEnv(scriptInstance)
	local world = self
	local env = {
		game = self.game,
		workspace = self.workspace,
		script = scriptInstance,
		require = function(target)
			return world:require(target)
		end,
		Instance = { new = self.newInstance },
		Enum = Mock.Enum,
		Vector2 = Mock.Vector2,
		Vector3 = Mock.Vector3,
		CFrame = Mock.CFrame,
		TweenInfo = Mock.TweenInfo,
		Random = Mock.Random,
		Font = Mock.Font,
		UDim = Mock.UDim,
		UDim2 = Mock.UDim2,
		Color3 = Mock.Color3,
		typeof = Mock.typeof,
		task = task,
		tick = os.clock,
		time = os.clock,
		print = function(...)
			world:log("print", ...)
		end,
		warn = function(...)
			world:log("warn", ...)
		end,
	}
	return setmetatable(env, { __index = BASE_GLOBALS })
end

function World:compile(scriptInstance)
	return luau.load(scriptInstance.Source, {
		debugName = scriptInstance:GetFullName(),
		environment = self:makeEnv(scriptInstance),
	})
end

function World:require(target)
	if not Mock.isInstance(target) or not target:IsA("ModuleScript") then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	local cached = self.cache[target]
	if cached then
		if cached.loading then
			error(`Requested module was required recursively: {target:GetFullName()}`, 2)
		end
		return cached.value
	end
	local entry = { loading = true }
	self.cache[target] = entry
	local ok, result = pcall(function()
		local results = table.pack(self:compile(target)())
		if results.n ~= 1 then
			error("Module code did not return exactly one value")
		end
		return results[1]
	end)
	if not ok then
		self.cache[target] = nil
		error(`{result}\nRequested module experienced an error while loading: {target:GetFullName()}`, 2)
	end
	entry.loading = false
	entry.value = result
	return result
end

function World:runScript(scriptInstance)
	local chunk = self:compile(scriptInstance)
	task.spawn(function()
		local ok, err = xpcall(chunk, debug.traceback)
		if not ok then
			self:log("error", err)
			table.insert(Mock.uncaughtErrors, `[{self.Name}] {err}`)
		end
	end)
end

function World:startFrames()
	task.spawn(function()
		local last = os.clock()
		while self.Running do
			task.wait(1 / 60)
			local now = os.clock()
			local deltaTime = now - last
			last = now
			if self.Kind == "Client" then
				self.RunService.RenderStepped:Fire(deltaTime)
			end
			self.RunService.Heartbeat:Fire(deltaTime)
		end
	end)
end

function World.new(kind, name, options)
	local self = setmetatable({}, World)
	self.Kind = kind
	self.Name = name
	self.Logs = {}
	self.Verbose = options.verbose
	self.Running = true
	self.cache = {}

	self.newInstance = function(className, instanceName)
		local instance = Mock.newInstance(className, instanceName)
		if options.onCreate then
			options.onCreate(self, instance)
		end
		return instance
	end

	local game = Mock.newInstance("DataModel", "game")
	self.game = game
	self.closeCallbacks = {}
	game.BindToClose = function(_, callback)
		table.insert(self.closeCallbacks, callback)
	end
	function game:GetService(serviceName)
		local service = game:FindFirstChild(serviceName)
		if not service then
			error(`'{serviceName}' is not a valid Service name (simulado)`)
		end
		return service
	end

	local function service(className)
		local instance = Mock.newInstance(className)
		instance.Parent = game
		return instance
	end

	self.workspace = service("Workspace")
	self.workspace.GetServerTimeNow = function()
		return os.clock()
	end
	service("ReplicatedStorage")
	service("ServerScriptService")
	service("ServerStorage")
	service("Lighting")
	local guiService = service("GuiService")
	guiService.SelectedObject = nil
	local camera = Mock.newInstance("Camera", "Camera")
	camera.ViewportSize = Mock.Vector2.new(options.viewportWidth or 1280, options.viewportHeight or 720)
	camera.Parent = self.workspace
	self.workspace.CurrentCamera = camera
	self.Camera = camera
	service("SoundService")
	local starterPlayer = service("StarterPlayer")
	Mock.newInstance("StarterPlayerScripts").Parent = starterPlayer

	local runService = service("RunService")
	runService.IsServer = function()
		return kind == "Server"
	end
	runService.IsClient = function()
		return kind == "Client"
	end
	runService.IsStudio = function()
		return options.studio ~= false
	end
	runService.RenderStepped = Mock.newSignal()
	runService.Heartbeat = Mock.newSignal()
	runService.Stepped = Mock.newSignal()
	self.RunService = runService

	-- CollectionService simulado ------------------------------------------------------
	local collection = service("CollectionService")
	local addedSignals, removedSignals = {}, {}
	local function signalFor(map, tag)
		map[tag] = map[tag] or Mock.newSignal()
		return map[tag]
	end
	local function inGame(instance)
		return instance == game or (instance ~= nil and instance:IsDescendantOf(game))
	end
	local function forTagged(root, callback)
		local list = { root }
		for _, descendant in root:GetDescendants() do
			table.insert(list, descendant)
		end
		for _, instance in list do
			if instance == collection then
				continue
			end
			for _, tag in instance:GetTags() do
				callback(instance, tag)
			end
		end
	end
	collection.AddTag = function(_, instance, tag)
		instance:AddTag(tag)
	end
	collection.RemoveTag = function(_, instance, tag)
		instance:RemoveTag(tag)
	end
	collection.HasTag = function(_, instance, tag)
		return instance:HasTag(tag)
	end
	collection.GetTagged = function(_, tag)
		local list = {}
		for _, descendant in game:GetDescendants() do
			if descendant ~= collection and descendant:HasTag(tag) then
				table.insert(list, descendant)
			end
		end
		return list
	end
	collection.GetInstanceAddedSignal = function(_, tag)
		return signalFor(addedSignals, tag)
	end
	collection.GetInstanceRemovedSignal = function(_, tag)
		return signalFor(removedSignals, tag)
	end
	self.collectionListener = {
		parentChanged = function(instance, oldParent, newParent)
			if not self.Running then
				return
			end
			local wasIn, isIn = inGame(oldParent), inGame(newParent)
			if isIn and not wasIn then
				forTagged(instance, function(tagged, tag)
					signalFor(addedSignals, tag):Fire(tagged)
				end)
			elseif wasIn and not isIn then
				forTagged(instance, function(tagged, tag)
					signalFor(removedSignals, tag):Fire(tagged)
				end)
			end
		end,
		tagAdded = function(instance, tag)
			if self.Running and inGame(instance.Parent) then
				signalFor(addedSignals, tag):Fire(instance)
			end
		end,
		tagRemoved = function(instance, tag)
			if self.Running and inGame(instance.Parent) then
				signalFor(removedSignals, tag):Fire(instance)
			end
		end,
	}
	table.insert(Mock.parentListeners, self.collectionListener)

	-- TweenService simulado: aplica o valor final na hora.
	local tweenService = service("TweenService")
	tweenService.Create = function(_, instance, _info, goals)
		local tween = { Completed = Mock.newSignal() }
		function tween:Play()
			for key, value in goals do
				instance[key] = value
			end
			tween.Completed:Fire(Mock.Enum.PlaybackState.Completed)
		end
		function tween:Cancel() end
		function tween:Pause() end
		return tween
	end

	local promptService = service("ProximityPromptService")
	for _, signalName in
		{ "PromptShown", "PromptHidden", "PromptTriggered", "PromptButtonHoldBegan", "PromptButtonHoldEnded" }
	do
		promptService[signalName] = Mock.newSignal()
	end
	self.ProximityPromptService = promptService

	local players = service("Players")
	players.PlayerAdded = Mock.newSignal()
	players.PlayerRemoving = Mock.newSignal()
	players.GetPlayers = function()
		local list = {}
		for _, child in players:GetChildren() do
			if child.ClassName == "Player" then
				table.insert(list, child)
			end
		end
		return list
	end
	self.Players = players

	local userInputService = service("UserInputService")
	userInputService.InputBegan = Mock.newSignal()
	userInputService.InputEnded = Mock.newSignal()
	userInputService.InputChanged = Mock.newSignal()
	userInputService.LastInputTypeChanged = Mock.newSignal()
	userInputService.TouchEnabled = false
	userInputService.KeyboardEnabled = true
	userInputService.GamepadEnabled = false
	userInputService.MouseEnabled = true
	self.LastInputType = Mock.Enum.UserInputType.Keyboard
	userInputService.GetLastInputType = function()
		return self.LastInputType
	end
	self.UserInputService = userInputService

	local localizationService = service("LocalizationService")
	localizationService.RobloxLocaleId = options.locale or "pt-br"

	return self
end

return World
