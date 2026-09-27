# NIGHT SHIFT: 4AM — Guia do dono do jogo

Tudo o que você precisa para abrir, testar, completar e publicar o jogo.

---

## 1. Abrir e jogar no Studio

1. Baixe o arquivo **`NightShift.rbxlx`**.
2. Abra o **Roblox Studio** → **File → Open from File…** → escolha o arquivo.
3. Abra a janela de mensagens: **View → Output**.
4. Aperte **Play** (F5).

Você aparece numa sala escura (o lobby). Pelo menu à direita:

1. **JOGAR** → **CRIAR TURNO**
2. **ESTOU PRONTO** → **INICIAR TURNO**

Você vai para o posto de gasolina às **04:00**. O turno dura cerca de **15 minutos** e termina às 05:00.

**Com 2 ou mais jogadores:** aba **Test → Clients and Servers → 2 Players → Start**.

**Onde está o mapa?** O posto fica em **ServerStorage → Maps → GasStation** e só aparece no mundo quando o turno começa. Para vê-lo no modo de edição, arraste temporariamente uma cópia para o **Workspace**. Apague a cópia depois.

## 2. Controles

| Ação | PC | Celular | Controle |
|---|---|---|---|
| Interagir | E (segurar quando pedir) | botão INTERAGIR | X |
| Lanterna | F | botão LANTERNA | Y |
| Câmeras: trocar / sair | ← → / Backspace | botões na tela | direcional / B |
| Respostas de diálogo | 1–4 | toque | selecionar + A |
| Painel de debug | F3 | — | direcional ↓ |
| Painel de admin | F4 | — | — |

## 3. Painel de admin (para testar tudo rápido)

- Funciona no Studio, e no jogo publicado só para o seu UserId (**2381958322**, já configurado).
- Com o turno rodando, aperte **F4** para abrir o painel.
- Botões disponíveis:
  - dar CASH;
  - pular 5 minutos;
  - encerrar o turno;
  - ligar ou desligar o diretor;
  - blackout;
  - zerar a tensão;
  - forçar a entidade (Watching, Stalking, Manifest, Hunt);
  - teleportar para cada área;
  - disparar **qualquer evento**.
- O **F3** mostra o painel de debug: ping, FPS, fase, minuto, eventos, tarefas, estado da entidade, clima, tensão e se o salvamento está usando DataStore ou memória.

**Antes de publicar:** em `ReplicatedStorage → Shared → Config → GameConfig`, mude `DEBUG_MODE = false`.

## 4. O que você precisa preencher (nada foi inventado)

| O quê | Onde | Como |
|---|---|---|
| **Sons** | `Shared → Definitions → SoundDefinitions` | Troque `""` por `"rbxassetid://NUMERO"`. Pegue os números na Toolbox → Audio. Sem som configurado, a legenda aparece mesmo assim. |
| **VIP (GamePass)** | `Shared → Definitions → ProductDefinitions` | Crie o GamePass em create.roblox.com → Monetization e troque `GAMEPASS_ID_HERE` pelo número. |
| **NIGHT TOKENS (Dev Products)** | mesmo arquivo | Crie 3 produtos (100, 550 e 1200 tokens) e troque cada `PRODUCT_ID_HERE`. |
| **Badges** | `Shared → Definitions → BadgeDefinitions` | Crie as badges e troque cada `BADGE_ID_HERE`. Sem isso, as conquistas funcionam (ficam salvas no perfil), mas a badge oficial não é entregue. |
| **Emotes** | `Shared → Definitions → ItemDefinitions` | Troque `ANIMATION_ID_HERE` por uma animação sua. |
| **Places (opcional)** | `Shared → Config → GameConfig → PLACE_IDS` | Só para o modo Teleport (seção 6). |

## 5. Publicar

1. **File → Publish to Roblox**. Dê nome e descrição.
2. **Game Settings → Security → Enable Studio Access to API Services**. Isso liga o salvamento real (DataStore), também no Studio.
3. Mude `DEBUG_MODE = false` e publique de novo.
4. Na página do jogo (create.roblox.com), configure ícone, miniaturas, gênero (Horror) e número máximo de jogadores. Sugestão para o modo Local: **4**.

No **modo Local**, que é o padrão, cada servidor roda **um turno por vez**. Quem estiver no lobby espera o turno acabar.

## 6. Modo Teleport (recomendado quando o jogo crescer)

Cada equipe ganha seu próprio servidor, com luz e clima independentes. Para ativar:

1. Em create.roblox.com → seu jogo → **Places**, crie um **segundo place** (o "Turno") e publique nele **o mesmo arquivo**.
2. Copie os IDs dos dois places para `GameConfig → PLACE_IDS` (`Lobby` e `Shift`).
3. Mude `LAUNCH_MODE = "Teleport"` e publique **nos dois places**.

Teleporte não funciona dentro do Studio. Lá o jogo usa o modo Local automaticamente.

## 7. Editar o mapa à mão

A cópia em **ServerStorage → Maps → GasStation** é a que o jogo usa. Você pode mover, recolorir e adicionar coisas à vontade. Mantenha:

- **Spawns** (Parts onde a equipe aparece);
- **Zones** (caixas invisíveis com o atributo `Zone`);
- **SecurityCameras**, **EventAnchors**, **EntityNodes** e **NPCPath** (os nomes são usados pelo código);
- Partes interativas: tag **Interactable** + atributos. Exemplo: `InteractionType = Task`, `TaskId`, `Point`.

Para voltar ao mapa original, apague a pasta: o jogo gera o posto por código de novo.

## 8. O que existe no jogo

- **Lobby:**
  - turnos para 1 a 4 jogadores, com pronto e líder;
  - perfil, loja, inventário, ranking, configurações e créditos.
- **Turno:**
  - **Relógio e horários especiais:** 04:00 → 05:00, com 04:17, 04:33 e 04:44.
  - **Clima e luz:** clima sorteado (limpo, neblina, chuva, tempestade); luzes por área; blackout com luzes de emergência.
  - **Tarefas:** 8 tipos, 5 sorteadas por turno, liberadas ao longo da noite e feitas em equipe.
  - **Eventos:** 17 eventos, com raridades de COMMON a SECRET, controlados por um "diretor" (começo calmo, final pesado). Alguns só um jogador percebe, outros só aparecem nas câmeras.
  - **Tensão invisível:** muda cores e sons, cria sons falsos e ativa batimentos.
  - **Câmeras de segurança:** 6 câmeras com efeito de monitor.
  - **Clientes:** 8 tipos (comum, motorista, caminhoneiro, policial, entregador, senhor, estranho, sem registro), com diálogos de escolha.
  - **História:** 3 documentos da história (NightWorks, Rota 44, M. Alves, 4:44).
  - **Entidade:** observa, segue, aparece de relance e caça no fim ou depois do segredo. Voltar para a loja iluminada com a equipe salva.
  - **Morte:** quem morre vira espectador dos colegas vivos.
- **Fim:** tela TURNO CONCLUÍDO / FRACASSADO com XP, CASH, eventos, tarefas, NOVO NÍVEL e NOVO EVENTO.
- **Progressão:**
  - nível (até 100), CASH, NIGHT TOKENS e estatísticas;
  - 6 conquistas, com recompensas;
  - 5 rankings.
- **Loja:** 6 categorias (lanternas, uniformes, títulos, acessórios, efeitos, emotes), só cosmética. VIP e compras de tokens têm proteção contra entrega duplicada.
- **Salvamento:** DataStore com trava de sessão e novas tentativas.
- **Acessibilidade:** legendas, redução de flashes, efeitos reduzidos, volumes e sensibilidade.

## 9. O que eu não consegui verificar (só você no Studio)

Eu testei a lógica com 132 testes automáticos num simulador. O simulador **não desenha a tela e não tem física**. Confira no Studio:

- a posição e o tamanho das interfaces (principalmente no celular: **Test → Device**);
- a aparência do posto: portas girando para o lado certo, luzes, sombras, placas;
- a caminhada dos clientes e da entidade: se atravessam objetos de um jeito estranho;
- se o volume e o clima estão bons;
- o desempenho em celular fraco: **View → Stats**, e o **MicroProfiler**.

Se algo estiver estranho, me mande um print ou o erro do Output.
