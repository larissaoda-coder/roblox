--!strict
-- Documentos espalhados pelo mapa (bilhetes, escalas, notas). Contam a história aos poucos.
-- Para adicionar: crie a entrada aqui, os textos em Strings e, no mapa, uma Part com
-- Tag "Interactable", InteractionType = "Document", DocumentId = "<Id>".

export type DocumentDefinition = { Id: string, TitleKey: string, BodyKey: string, Map: string }

local DOCUMENTS: { DocumentDefinition } = {
	{
		Id = "ShiftSchedule",
		TitleKey = "DOC_SCHEDULE_TITLE",
		BodyKey = "DOC_SCHEDULE_BODY",
		Map = "GasStation",
	},
	{ Id = "PreviousShiftNote", TitleKey = "DOC_NOTE_TITLE", BodyKey = "DOC_NOTE_BODY", Map = "GasStation" },
	{
		Id = "DeliveryNote",
		TitleKey = "DOC_DELIVERY_TITLE",
		BodyKey = "DOC_DELIVERY_BODY",
		Map = "GasStation",
	},
}

local byId: { [string]: DocumentDefinition } = {}
for _, document in DOCUMENTS do
	byId[document.Id] = document
end

local DocumentDefinitions = {}

function DocumentDefinitions.get(documentId: string): DocumentDefinition?
	return byId[documentId]
end

function DocumentDefinitions.getAll(): { DocumentDefinition }
	return table.clone(DOCUMENTS)
end

return DocumentDefinitions
