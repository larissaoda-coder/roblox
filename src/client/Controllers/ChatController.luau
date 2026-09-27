--!strict
-- Tag [VIP] no chat para quem tem o GamePass VIP (só visual).

local Players = game:GetService("Players")

local VIP_PREFIX = '<font color="#C8AAFF">[VIP]</font> '

local ChatController = {}

function ChatController:Init() end

function ChatController:Start()
	local ok, textChatService = pcall(function()
		return game:GetService("TextChatService")
	end)
	if not ok or not textChatService then
		return
	end
	(textChatService :: any).OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if player and player:GetAttribute("VIP") == true then
			properties.PrefixText = VIP_PREFIX .. message.PrefixText
		end
		return properties
	end
end

return ChatController
