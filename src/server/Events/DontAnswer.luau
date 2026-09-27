--!strict
-- SEGREDO. 04:44 — o telefone toca. Quem atende descobre por que não deveria.

local DontAnswer = {}

function DontAnswer.CanRun(ctx: any): boolean
	return not ctx.Services.Events:IsPhoneRinging()
end

function DontAnswer.Run(ctx: any)
	ctx.Services.Events:StartPhoneCall({
		LineKey = "PHONE_LINE_DONT_ANSWER",
		RingSeconds = 25,
		OnAnswer = function(player: Player)
			ctx.Witness({ player })
			task.wait(2)
			if not ctx.IsActive() then
				return
			end
			ctx.Services.Lighting:Blackout(10)
			ctx.Services.Audio:PlayAt("DistantScream", nil)
			ctx.Services.Events.SecretTriggered:Fire("DontAnswer", player)
		end,
	})
end

return DontAnswer
