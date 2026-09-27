--!strict
-- Lista de administradores. Este módulo fica no SERVIDOR: jogadores não conseguem lê-lo nem alterá-lo.
--
-- Para descobrir seu UserId: abra seu perfil no site do Roblox; o número na URL é o seu UserId.
-- Ex.: https://www.roblox.com/users/123456789/profile → 123456789

local AdminConfig = {
	ADMIN_USER_IDS = {
		-- 123456789, -- (exemplo) coloque seus UserIds aqui, separados por vírgula
	} :: { number },

	-- true: dentro do Roblox Studio, qualquer jogador de teste é admin.
	-- Não tem efeito no jogo publicado (lá o Studio não existe).
	STUDIO_PLAYERS_ARE_ADMINS = true,
}

return table.freeze(AdminConfig)
