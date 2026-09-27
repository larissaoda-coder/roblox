--!strict
-- Diálogos curtos (conversas naturais, não textos gigantes). Ficam no servidor: o cliente só recebe
-- a fala atual, então ninguém lê respostas secretas antes da hora.
--
-- Nó: { TextKey, Choices = { { TextKey, Next?, Action?, Condition? } }, Action? }
--   Next = nome do próximo nó (sem Next = a conversa termina)
--   Action = "Serve" | "Leave" | "Tension:<n>" | "Discover:<EventId>"
--   Condition = "AfterMinute:<n>" | "Chance:<0-1>"  (a escolha só aparece se a condição for verdadeira)
-- StartVariants: falas iniciais alternativas raras { Node, Chance }.

export type Choice = { TextKey: string, Next: string?, Action: string?, Condition: string? }
export type Node = { TextKey: string, Choices: { Choice }, Action: string? }
export type Dialogue = {
	Start: string,
	StartVariants: { { Node: string, Chance: number } }?,
	Nodes: { [string]: Node },
}

local BYE = { TextKey = "DLG_CHOICE_BYE", Action = "Serve" }

local DIALOGUES: { [string]: Dialogue } = {
	Commuter = {
		Start = "greet",
		Nodes = {
			greet = {
				TextKey = "DLG_COMMUTER_1",
				Choices = { { TextKey = "DLG_CHOICE_COFFEE", Next = "coffee" }, BYE },
			},
			coffee = { TextKey = "DLG_COMMUTER_2", Choices = { BYE } },
		},
	},
	Driver = {
		Start = "greet",
		Nodes = {
			greet = {
				TextKey = "DLG_DRIVER_1",
				Choices = {
					{ TextKey = "DLG_CHOICE_DIRECTIONS", Next = "directions" },
					{ TextKey = "DLG_CHOICE_DONT_KNOW", Next = "unknown" },
				},
			},
			directions = { TextKey = "DLG_DRIVER_2", Choices = { BYE } },
			unknown = { TextKey = "DLG_DRIVER_3", Choices = { BYE } },
		},
	},
	Trucker = {
		Start = "greet",
		StartVariants = { { Node = "warning", Chance = 0.25 } },
		Nodes = {
			greet = {
				TextKey = "DLG_TRUCKER_1",
				Choices = { { TextKey = "DLG_CHOICE_LONG_NIGHT", Next = "road" }, BYE },
			},
			road = { TextKey = "DLG_TRUCKER_2", Choices = { BYE } },
			warning = {
				TextKey = "DLG_TRUCKER_WARNING",
				Choices = { { TextKey = "DLG_CHOICE_WHY", Next = "why" }, BYE },
			},
			why = {
				TextKey = "DLG_TRUCKER_WHY",
				Choices = { { TextKey = "DLG_CHOICE_BYE", Action = "Tension:8" } },
			},
		},
	},
	Police = {
		Start = "greet",
		Nodes = {
			greet = {
				TextKey = "DLG_POLICE_1",
				Choices = {
					{ TextKey = "DLG_CHOICE_NOTHING", Next = "nothing" },
					{ TextKey = "DLG_CHOICE_SAW_SOMEONE", Next = "saw", Condition = "AfterMinute:30" },
				},
			},
			nothing = { TextKey = "DLG_POLICE_2", Choices = { BYE } },
			saw = {
				TextKey = "DLG_POLICE_SAW",
				Choices = { { TextKey = "DLG_CHOICE_BYE", Action = "Tension:10" } },
			},
		},
	},
	Delivery = {
		Start = "greet",
		Nodes = {
			greet = {
				TextKey = "DLG_DELIVERY_1",
				Choices = { { TextKey = "DLG_CHOICE_SIGN", Next = "signed" }, BYE },
			},
			signed = { TextKey = "DLG_DELIVERY_2", Choices = { BYE } },
		},
	},
	OldMan = {
		Start = "greet",
		Nodes = {
			greet = {
				TextKey = "DLG_OLDMAN_1",
				Choices = { { TextKey = "DLG_CHOICE_REALLY", Next = "story" }, BYE },
			},
			story = {
				TextKey = "DLG_OLDMAN_2",
				Choices = { { TextKey = "DLG_CHOICE_WHAT_HAPPENED", Next = "happened" }, BYE },
			},
			happened = {
				TextKey = "DLG_OLDMAN_3",
				Choices = { { TextKey = "DLG_CHOICE_BYE", Action = "Discover:OldManStory" } },
			},
		},
	},
	Strange = {
		Start = "greet",
		Nodes = {
			greet = {
				TextKey = "DLG_STRANGE_1",
				Choices = {
					{ TextKey = "DLG_CHOICE_TIME", Next = "time" },
					{ TextKey = "DLG_CHOICE_BYE", Action = "Leave" },
				},
			},
			time = {
				TextKey = "DLG_STRANGE_2",
				Choices = { { TextKey = "DLG_CHOICE_BYE", Action = "Tension:12" } },
			},
		},
	},
	NoRecord = {
		Start = "greet",
		Nodes = {
			greet = {
				TextKey = "DLG_NORECORD_1",
				Choices = {
					{ TextKey = "DLG_CHOICE_WHO", Next = "who" },
					{ TextKey = "DLG_CHOICE_BYE", Action = "Discover:CustomerNoRecord" },
				},
			},
			who = {
				TextKey = "DLG_NORECORD_2",
				Choices = { { TextKey = "DLG_CHOICE_BYE", Action = "Discover:CustomerNoRecord" } },
			},
		},
	},
}

-- Validação: todo "Next" precisa existir.
for dialogueId, dialogue in DIALOGUES do
	assert(dialogue.Nodes[dialogue.Start], `[DialogueDefinitions] {dialogueId}: nó inicial não existe`)
	for nodeId, node in dialogue.Nodes do
		for _, choice in node.Choices do
			assert(
				choice.Next == nil or dialogue.Nodes[choice.Next],
				`[DialogueDefinitions] {dialogueId}.{nodeId}: Next inválido`
			)
		end
	end
end

local DialogueDefinitions = {}

function DialogueDefinitions.get(dialogueId: string): Dialogue?
	return DIALOGUES[dialogueId]
end

return DialogueDefinitions
