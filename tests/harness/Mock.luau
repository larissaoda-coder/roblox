--!nocheck
-- Simulação mínima da API do Roblox para rodar o código de src/ fora do Studio (com Lune).
-- Implementa apenas o que o jogo usa. Acessar uma propriedade/filho inexistente gera erro,
-- assim como no Roblox, para que erros de digitação apareçam nos testes.

local task = require("@lune/task")

local Mock = {}

-- Erros que aconteceram dentro de eventos (threads separadas). O Test.run reprova o teste se houver algum.
Mock.uncaughtErrors = {}

local function safeCall(callback, ...)
	local ok, err = xpcall(callback, debug.traceback, ...)
	if not ok then
		table.insert(Mock.uncaughtErrors, tostring(err))
	end
end

local instanceSet = setmetatable({}, { __mode = "k" })

-- Signal (RBXScriptSignal) -----------------------------------------------------------
function Mock.newSignal()
	local listeners = {}
	local signal = { __mockType = "RBXScriptSignal" }

	function signal:Connect(callback)
		local connection = { __mockType = "RBXScriptConnection", Connected = true }
		function connection:Disconnect()
			connection.Connected = false
			local index = table.find(listeners, connection)
			if index then
				table.remove(listeners, index)
			end
		end
		connection.callback = callback
		table.insert(listeners, connection)
		return connection
	end

	function signal:Once(callback)
		local connection
		connection = signal:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)
		return connection
	end

	function signal:Fire(...)
		for _, connection in table.clone(listeners) do
			if connection.Connected then
				task.spawn(safeCall, connection.callback, ...)
			end
		end
	end

	function signal:Wait()
		local thread = coroutine.running()
		signal:Once(function(...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	return signal
end

-- Random (determinístico por seed, algoritmo LCG) -----------------------------------------
Mock.Random = {
	new = function(seed)
		local state = math.floor(seed or os.clock() * 1000) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		local random = {}
		local function nextFloat()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
		function random:NextNumber(min, max)
			min, max = min or 0, max or 1
			return min + nextFloat() * (max - min)
		end
		function random:NextInteger(min, max)
			return min + math.floor(nextFloat() * (max - min + 1))
		end
		return random
	end,
}

-- Enum ------------------------------------------------------------------------------
local enumCache = {}
Mock.Enum = setmetatable({}, {
	__index = function(_, enumType)
		enumCache[enumType] = enumCache[enumType]
			or setmetatable({}, {
				__index = function(items, itemName)
					local item = { __mockType = "EnumItem", EnumType = enumType, Name = itemName }
					rawset(items, itemName, item)
					return item
				end,
			})
		return enumCache[enumType]
	end,
})

-- Datatypes ---------------------------------------------------------------------------
local function datatype(typeName, fields)
	fields.__mockType = typeName
	return fields
end

Mock.Vector2 = {
	new = function(x, y)
		return datatype("Vector2", { X = x or 0, Y = y or 0 })
	end,
}
local Vector3Meta = {}
local function newVector3(x, y, z)
	return setmetatable({ __mockType = "Vector3", X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end
Vector3Meta.__add = function(a, b)
	return newVector3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3Meta.__sub = function(a, b)
	return newVector3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Meta.__mul = function(a, b)
	if type(b) == "number" then
		return newVector3(a.X * b, a.Y * b, a.Z * b)
	end
	return newVector3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3Meta.__div = function(a, b)
	if type(b) == "number" then
		return newVector3(a.X / b, a.Y / b, a.Z / b)
	end
	return newVector3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3Meta.__unm = function(a)
	return newVector3(-a.X, -a.Y, -a.Z)
end
Vector3Meta.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3Meta.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif key == "Unit" then
		local magnitude = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		return newVector3(self.X / magnitude, self.Y / magnitude, self.Z / magnitude)
	end
	return nil
end
Mock.Vector3 = { new = newVector3, zero = newVector3(0, 0, 0) }

-- CFrame simplificado: guarda posição e ângulo Y acumulado (suficiente para os testes).
local CFrameMeta = {}
local function newCFrame(position, yaw)
	return setmetatable({ __mockType = "CFrame", Position = position, Yaw = yaw or 0 }, CFrameMeta)
end
CFrameMeta.__mul = function(a, b)
	if rawget(b, "__mockType") == "CFrame" then
		return newCFrame(a.Position + b.Position, a.Yaw + b.Yaw)
	end
	return a.Position + b
end
CFrameMeta.__add = function(a, b)
	return newCFrame(a.Position + b, a.Yaw)
end
Mock.CFrame = {
	new = function(x, y, z)
		local position = if type(x) == "table" then x else newVector3(x or 0, y or 0, z or 0)
		return newCFrame(position, 0)
	end,
	Angles = function(_, yaw, _)
		return newCFrame(newVector3(0, 0, 0), yaw or 0)
	end,
	lookAt = function(position, _target)
		return newCFrame(position, 0)
	end,
}
Mock.Font = {
	fromEnum = function(enumItem)
		return datatype("Font", { Family = enumItem.Name })
	end,
	new = function(family, weight)
		return datatype("Font", { Family = family, Weight = weight })
	end,
}
Mock.NumberRange = {
	new = function(min, max)
		return datatype("NumberRange", { Min = min, Max = max or min })
	end,
}
Mock.NumberSequence = {
	new = function(...)
		return datatype("NumberSequence", { Args = table.pack(...) })
	end,
}
Mock.ColorSequence = {
	new = function(...)
		return datatype("ColorSequence", { Args = table.pack(...) })
	end,
}
Mock.TweenInfo = {
	new = function(...)
		return datatype("TweenInfo", { Args = table.pack(...) })
	end,
}
Mock.UDim = {
	new = function(scale, offset)
		return datatype("UDim", { Scale = scale or 0, Offset = offset or 0 })
	end,
}
Mock.UDim2 = {
	new = function(xs, xo, ys, yo)
		return datatype("UDim2", { X = Mock.UDim.new(xs, xo), Y = Mock.UDim.new(ys, yo) })
	end,
	fromScale = function(x, y)
		return Mock.UDim2.new(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return Mock.UDim2.new(0, x, 0, y)
	end,
}
Mock.Color3 = {
	fromRGB = function(r, g, b)
		return datatype("Color3", { R = r / 255, G = g / 255, B = b / 255 })
	end,
	new = function(r, g, b)
		return datatype("Color3", { R = r, G = g, B = b })
	end,
}

function Mock.typeof(value)
	if instanceSet[value] then
		return "Instance"
	end
	if type(value) == "table" and rawget(value, "__mockType") then
		return rawget(value, "__mockType")
	end
	return typeof(value)
end

-- Instance ------------------------------------------------------------------------------
local SUPERCLASSES = {
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	Part = { "BasePart", "PVInstance" },
	SpawnLocation = { "Part", "BasePart", "PVInstance" },
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	ImageButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	ImageLabel = { "GuiObject", "GuiBase2d" },
	TextBox = { "GuiObject", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	ScrollingFrame = { "GuiObject", "GuiBase2d" },
	Model = { "PVInstance" },
	SurfaceLight = { "Light" },
	SpotLight = { "Light" },
	PointLight = { "Light" },
	WedgePart = { "BasePart", "PVInstance" },
}

-- Eventos específicos de algumas classes.
local CLASS_SIGNALS = {
	TextButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" },
	ImageButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" },
	ProximityPrompt = {
		"Triggered",
		"PromptButtonHoldBegan",
		"PromptButtonHoldEnded",
		"PromptShown",
		"PromptHidden",
	},
	TextBox = { "FocusLost", "Focused" },
	Sound = { "Ended", "Played" },
	Humanoid = { "Died", "HealthChanged" },
}

local DEFAULTS = {
	Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16 },
	ProximityPrompt = {
		Enabled = true,
		HoldDuration = 0,
		MaxActivationDistance = 10,
		RequiresLineOfSight = true,
	},
	Part = { Size = nil, Anchored = false, CanCollide = true, Transparency = 0 },
	ScreenGui = { Enabled = true, ResetOnSpawn = true, DisplayOrder = 0, IgnoreGuiInset = false },
	TextLabel = { Text = "Label", Visible = true },
	Frame = { Visible = true },
}

-- Propriedades que podem ser nil sem gerar erro.
local NILLABLE = {
	OnServerInvoke = true,
	OnClientInvoke = true,
	PrimaryPart = true,
	Adornee = true,
	SelectedObject = true,
	Character = true,
	CameraSubject = true,
	ProcessReceipt = true,
	OnIncomingMessage = true,
}

-- Ouvintes globais (usados pelo CollectionService simulado de cada mundo).
Mock.parentListeners = {}
Mock.tagListeners = {}

function Mock.isInstance(value)
	return instanceSet[value] == true
end

function Mock.newInstance(className, name)
	local props = { ClassName = className, Name = name or className }
	for key, value in DEFAULTS[className] or {} do
		props[key] = value
	end
	local children = {}
	local attributes = {}
	local parent = nil
	local destroyed = false
	local self = {}
	instanceSet[self] = true

	local childAdded = Mock.newSignal()
	local childRemoved = Mock.newSignal()
	local ancestryChanged = Mock.newSignal()
	local destroying = Mock.newSignal()
	local tags = {}
	local attributeChanged = Mock.newSignal()
	local attributeSignals = {}
	local propertySignals = {}

	local methods = {}

	function methods:FindFirstChild(childName)
		for _, child in children do
			if child.Name == childName then
				return child
			end
		end
		return nil
	end

	function methods:FindFirstChildOfClass(childClass)
		for _, child in children do
			if child.ClassName == childClass then
				return child
			end
		end
		return nil
	end

	function methods:WaitForChild(childName, timeout)
		local limit = timeout or 5
		local startedAt = os.clock()
		repeat
			local child = self:FindFirstChild(childName)
			if child then
				return child
			end
			task.wait(0.02)
		until os.clock() - startedAt >= limit
		if timeout == nil then
			error(`Infinite yield (simulado): {self:GetFullName()}:WaitForChild("{childName}")`)
		end
		return nil
	end

	function methods:GetChildren()
		return table.clone(children)
	end

	function methods:GetDescendants()
		local result = {}
		for _, child in children do
			table.insert(result, child)
			for _, descendant in child:GetDescendants() do
				table.insert(result, descendant)
			end
		end
		return result
	end

	function methods:IsA(target)
		if target == "Instance" or target == className then
			return true
		end
		return table.find(SUPERCLASSES[className] or {}, target) ~= nil
	end

	function methods:IsDescendantOf(ancestor)
		local current = parent
		while current do
			if current == ancestor then
				return true
			end
			current = current.Parent
		end
		return false
	end

	function methods:GetFullName()
		local parts = { props.Name }
		local current = parent
		while current and current.ClassName ~= "DataModel" do
			table.insert(parts, 1, current.Name)
			current = current.Parent
		end
		return table.concat(parts, ".")
	end

	function methods:SetAttribute(key, value)
		local valueType = typeof(value)
		if value ~= nil and valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" then
			error(`SetAttribute: tipo {valueType} não suportado em atributos`)
		end
		if attributes[key] == value then
			return
		end
		attributes[key] = value
		attributeChanged:Fire(key)
		if attributeSignals[key] then
			attributeSignals[key]:Fire()
		end
	end

	function methods:GetPropertyChangedSignal(property)
		propertySignals[property] = propertySignals[property] or Mock.newSignal()
		return propertySignals[property]
	end

	function methods:GetAttributeChangedSignal(key)
		attributeSignals[key] = attributeSignals[key] or Mock.newSignal()
		return attributeSignals[key]
	end

	function methods:GetAttribute(key)
		return attributes[key]
	end

	function methods:GetAttributes()
		return table.clone(attributes)
	end

	function methods:AddTag(tag)
		if not tags[tag] then
			tags[tag] = true
			for _, listener in Mock.parentListeners do
				listener.tagAdded(self, tag)
			end
		end
	end

	function methods:RemoveTag(tag)
		if tags[tag] then
			tags[tag] = nil
			for _, listener in Mock.parentListeners do
				listener.tagRemoved(self, tag)
			end
		end
	end

	function methods:HasTag(tag)
		return tags[tag] == true
	end

	function methods:GetTags()
		local list = {}
		for tag in tags do
			table.insert(list, tag)
		end
		return list
	end

	function methods:FindFirstChildWhichIsA(targetClass, recursive)
		for _, child in children do
			if child:IsA(targetClass) then
				return child
			end
			if recursive then
				local found = child:FindFirstChildWhichIsA(targetClass, true)
				if found then
					return found
				end
			end
		end
		return nil
	end

	function methods:FindFirstAncestorWhichIsA(targetClass)
		local current = parent
		while current do
			if current:IsA(targetClass) then
				return current
			end
			current = current.Parent
		end
		return nil
	end

	function methods:FindFirstAncestor(ancestorName)
		local current = parent
		while current do
			if current.Name == ancestorName then
				return current
			end
			current = current.Parent
		end
		return nil
	end

	function methods:Play()
		props.IsPlaying = true
	end

	function methods:Stop()
		props.IsPlaying = false
	end

	function methods:InputHoldBegin()
		props.__holding = true
	end

	function methods:InputHoldEnd()
		props.__holding = false
	end

	function methods:Clone()
		local copy = Mock.newInstance(className, props.Name)
		for key, value in props do
			if key ~= "ClassName" and key ~= "Name" then
				copy[key] = value
			end
		end
		for key, value in attributes do
			copy:SetAttribute(key, value)
		end
		for tag in tags do
			copy:AddTag(tag)
		end
		for _, child in children do
			child:Clone().Parent = copy
		end
		return copy
	end

	function methods:PivotTo(cframe)
		props.__pivot = cframe
		local root = self:FindFirstChild("HumanoidRootPart")
		if root then
			root.Position = cframe.Position
		end
	end

	function methods:GetPivot()
		return props.__pivot or Mock.CFrame.new(props.Position or newVector3(0, 0, 0))
	end

	function methods:ClearAllChildren()
		for _, child in table.clone(children) do
			child:Destroy()
		end
	end

	function methods:Destroy()
		if destroyed then
			return
		end
		destroying:Fire()
		for _, child in table.clone(children) do
			child:Destroy()
		end
		self.Parent = nil
		destroyed = true
	end

	local function setParent(newParent)
		if destroyed then
			error(`The Parent property of {props.Name} is locked`)
		end
		if newParent ~= nil and not instanceSet[newParent] then
			error("Parent precisa ser uma Instance")
		end
		local oldParent = parent
		if parent then
			parent.__removeChild(self)
		end
		parent = newParent
		if newParent then
			newParent.__addChild(self)
		end
		ancestryChanged:Fire(self, newParent)
		for _, listener in Mock.parentListeners do
			listener.parentChanged(self, oldParent, newParent)
		end
	end

	local internals = {
		__addChild = function(child)
			table.insert(children, child)
			childAdded:Fire(child)
		end,
		__removeChild = function(child)
			local index = table.find(children, child)
			if index then
				table.remove(children, index)
				childRemoved:Fire(child)
			end
		end,
		ChildAdded = childAdded,
		ChildRemoved = childRemoved,
		AncestryChanged = ancestryChanged,
		Destroying = destroying,
		AttributeChanged = attributeChanged,
	}
	for _, signalName in CLASS_SIGNALS[className] or {} do
		internals[signalName] = Mock.newSignal()
	end

	setmetatable(self, {
		__index = function(_, key)
			if key == "Parent" then
				return parent
			end
			local value = props[key]
			if value == nil then
				value = methods[key] or internals[key]
			end
			if value ~= nil then
				return value
			end
			local child = methods.FindFirstChild(self, key)
			if child then
				return child
			end
			if NILLABLE[key] then
				return nil
			end
			error(`{key} is not a valid member of {className} "{props.Name}"`, 2)
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				setParent(value)
			else
				-- Position e CFrame andam juntos, como no Roblox.
				if key == "CFrame" and type(value) == "table" and value.Position then
					props.Position = value.Position
				elseif
					key == "Position"
					and type(value) == "table"
					and rawget(value, "__mockType") == "Vector3"
				then
					props.CFrame = Mock.CFrame.new(value)
				end
				local changed = props[key] ~= value
				props[key] = value
				if changed and propertySignals[key] then
					propertySignals[key]:Fire()
				end
			end
		end,
		__tostring = function()
			return props.Name
		end,
	})

	return self
end

return Mock
