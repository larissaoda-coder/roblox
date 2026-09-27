--!strict
-- Documentos da história (bilhetes, escalas). Ler um documento pela primeira vez fica salvo no perfil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DocumentDefinitions = require(Shared.Definitions.DocumentDefinitions)
local Net = require(Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local InteractionService = require(script.Parent.InteractionService)

local DocumentService = {}

function DocumentService:Init()
	InteractionService:RegisterHandler("Document", {
		CanInteract = function(_player: Player, target: Instance)
			local documentId = target:GetAttribute("DocumentId")
			return type(documentId) == "string" and DocumentDefinitions.get(documentId) ~= nil, nil
		end,
		OnInteract = function(player: Player, target: Instance)
			local documentId = target:GetAttribute("DocumentId") :: string
			Net.Server.fire("ShowDocument", player, documentId)
			DataService:Update(player, "Documents", function(documents)
				if documents[documentId] == nil then
					documents[documentId] = os.time()
				end
				return documents
			end)
		end,
	})
end

return DocumentService
