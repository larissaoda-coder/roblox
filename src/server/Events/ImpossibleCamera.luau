--!strict
-- A câmera do gerador mostra a própria equipe lá fora — enquanto todos estão em outro lugar.

local ImpossibleCamera = {}

local CAMERA_ID = "CAM05"

local function anchor(ctx: any): BasePart?
	local anchors = ctx.Map:FindFirstChild("EventAnchors")
	local part = anchors and anchors:FindFirstChild("ImpossibleCamera")
	return if part and part:IsA("BasePart") then part else nil
end

function ImpossibleCamera.CanRun(ctx: any): boolean
	local part = anchor(ctx)
	if not part or not ctx.Services.Cameras:GetCameraCFrame(CAMERA_ID) then
		return false
	end
	-- Só é "impossível" se ninguém estiver perto do gerador.
	for _, player in ctx.Players do
		local position = ctx.Services.Map:GetCharacterPosition(player)
		if position and (position - part.Position).Magnitude < 40 then
			return false
		end
	end
	return true
end

function ImpossibleCamera.Run(ctx: any)
	local part = anchor(ctx) :: BasePart
	ctx.Services.Cameras:ShowAnomaly(
		CAMERA_ID,
		"Team",
		{ Position = part.Position, Count = #ctx.Players },
		20,
		function(player: Player)
			ctx.Witness({ player })
		end
	)
end

return ImpossibleCamera
