--!strict
-- A câmera do estoque mostra alguém parado lá dentro. Não há ninguém de verdade.

local CameraFigure = {}

local CAMERA_ID = "CAM03"

local function anchor(ctx: any): BasePart?
	local anchors = ctx.Map:FindFirstChild("EventAnchors")
	local part = anchors and anchors:FindFirstChild("CameraFigure")
	return if part and part:IsA("BasePart") then part else nil
end

function CameraFigure.CanRun(ctx: any): boolean
	return anchor(ctx) ~= nil and ctx.Services.Cameras:GetCameraCFrame(CAMERA_ID) ~= nil
end

function CameraFigure.Run(ctx: any)
	local part = anchor(ctx) :: BasePart
	ctx.Services.Cameras:ShowAnomaly(
		CAMERA_ID,
		"Figure",
		{ Position = part.Position, Count = 1 },
		25,
		function(player: Player)
			ctx.Witness({ player })
		end
	)
end

return CameraFigure
