--!strict
-- Máquina de estados simples com transições permitidas explícitas.
-- Uso:
--   local machine = StateMachine.new("Idle", { Idle = { "Loading" }, Loading = { "Idle" } })
--   machine:Transition("Loading")
-- Uma transição não listada gera erro (protege contra bugs de fluxo).

local Signal = require(script.Parent.Signal)

export type StateMachine = {
	Current: string,
	Changed: Signal.Signal, -- (newState, oldState)
	CanTransition: (self: StateMachine, to: string) -> boolean,
	Transition: (self: StateMachine, to: string) -> (),
}

local StateMachine = {}

function StateMachine.new(initial: string, transitions: { [string]: { string } }): StateMachine
	assert(transitions[initial], `[StateMachine] estado inicial "{initial}" não está nas transições`)
	local machine = {
		Current = initial,
		Changed = Signal.new(),
	} :: StateMachine

	function machine:CanTransition(to: string): boolean
		local allowed = transitions[self.Current]
		return allowed ~= nil and table.find(allowed, to) ~= nil
	end

	function machine:Transition(to: string)
		if not self:CanTransition(to) then
			error(`[StateMachine] transição inválida: {self.Current} → {to}`, 2)
		end
		local from = self.Current
		self.Current = to
		self.Changed:Fire(to, from)
	end

	return machine
end

return StateMachine
