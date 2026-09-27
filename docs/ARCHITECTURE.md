# NIGHT SHIFT: 4AM — Arquitetura do Projeto

> Documento-fonte da arquitetura. Toda nova funcionalidade deve seguir os nomes e a estrutura definidos aqui.
> Se algo aqui mudar, este arquivo é atualizado **antes** do código.

Status: **APROVADA**. Decisões confirmadas: A = modo Local primeiro · B = Rojo · C = DataService próprio · D = EN + PT-BR.

Fases concluídas: **Fase 1 — Arquitetura base** · **Fase 2 — Sistema de jogadores**.

---

## 1. Análise do projeto

NIGHT SHIFT: 4AM é um horror cooperativo de sessões curtas (10–20 min) cujo valor está em **pacing** e **variedade**, não em combate. Isso define as prioridades técnicas:

| Pilar de design | Consequência técnica |
|---|---|
| "Parece um trabalho normal que vai ficando errado" | Um **Director** (diretor de ritmo) controla *quando* os eventos acontecem, com base no relógio, na tensão e na fase da partida. Eventos não disparam aleatoriamente sem controle. |
| Rejogabilidade | Tudo é **orientado a dados** (definições em ModuleScripts): tarefas, eventos, NPCs, diálogos, itens. Cada partida sorteia uma combinação com uma *seed*. |
| Terror perceptivo (cada jogador vê/ouve coisas diferentes) | Separação clara entre eventos **globais** (servidor muda o mundo) e **perceptivos** (servidor manda um efeito só para um cliente). |
| Segredos descobertos pela comunidade | Definições e condições de eventos raros ficam **no servidor** (ServerScriptService), onde exploiters não conseguem ler. |
| Comercial / monetização / progressão | DataStore robusto com *session lock*, compras idempotentes, tudo validado no servidor. |
| Mobile e console como primeira classe | Interação baseada em **ProximityPrompt** (suporta teclado, toque e controle nativamente) com visual customizado. UI construída com layout responsivo. |
| Iluminação / clima mudam durante eventos | `Lighting` é **global por servidor** → cada turno precisa rodar em seu próprio servidor (ver Decisão A). |

---

## 2. Decisões de arquitetura (precisam de confirmação)

### Decisão A — Um place ou vários places?

O serviço `Lighting` do Roblox é único por servidor. Se duas equipes jogassem turnos no mesmo servidor, o blackout de uma equipe apagaria a névoa/iluminação da outra. Por isso:

**Arquitetura final (produção):**
- **Place 1 – Lobby**: jogadores formam equipe (Create Shift → Join → Ready).
- **Place 2 – Shift**: cada equipe é teleportada para um **servidor reservado** (`TeleportService:ReserveServer`) com o mapa escolhido. Ao final, volta para o Lobby.

**MVP / testes no Studio:** `TeleportService` não funciona no Studio. Então o `MatchService` terá dois modos de lançamento, com o mesmo código de partida:
- `LaunchMode = "Local"` → lobby e mapa no mesmo place; um turno por servidor (ideal para desenvolver e testar no Studio).
- `LaunchMode = "Teleport"` → produção, com places separados.

Recomendação: **começar em modo Local**, com o código já separado para que a troca para Teleport seja só configuração + publicação (Fase 21).

### Decisão B — Como o código chega ao Studio?

- **Opção 1 (recomendada): Rojo.** O código vive neste repositório Git (`src/`), e o plugin Rojo sincroniza automaticamente com o Studio. Evita centenas de copiar/colar, mantém histórico e permite eu entregar mudanças direto no repositório. Mapas e modelos continuam sendo construídos no Studio.
- **Opção 2: copiar e colar manualmente** cada script no Studio. Funciona, mas é propenso a erro (nome errado, local errado, arquivo desatualizado).

Em ambos os casos, cada entrega informará o nome, tipo e local exato no Explorer.

### Decisão C — Salvamento

- **Opção 1 (recomendada): `DataService` próprio** com `UpdateAsync`, *session lock*, autosave, retry com backoff, `BindToClose` e versão de schema. Controle total, sem dependência externa.
- **Opção 2: ProfileStore** (biblioteca da comunidade, amplamente usada). Menos código nosso, mas é uma dependência de terceiros.

### Decisão D — Idioma da interface

Recomendação: textos por **chave** (`"HUD_INTERACT"`) em um módulo de strings, com **inglês e português** desde o início. Custa pouco agora e é caro retrofitar depois (o público do Roblox é global).

---

## 3. Estrutura de pastas / objetos

Legenda de tipos: **[S]** Script · **[LS]** LocalScript · **[M]** ModuleScript · **[F]** Folder · **[RE]** RemoteEvent · **[RF]** RemoteFunction · **[Mdl]** Model

```
ReplicatedStorage
├── Shared [F]                       -- código visível para servidor E cliente
│   ├── Config [F]
│   │   ├── GameConfig [M]           -- DEBUG_MODE, LaunchMode, tempos, limites
│   │   ├── EconomyConfig [M]        -- recompensas, curva de XP
│   │   └── AudioConfig [M]          -- SoundGroups, volumes padrão
│   ├── Definitions [F]              -- dados PÚBLICOS (o cliente precisa ler)
│   │   ├── MapDefinitions [M]
│   │   ├── TaskDefinitions [M]      -- nome/descrição/duração exibidos no HUD
│   │   ├── ItemDefinitions [M]      -- itens da loja (cosméticos, títulos…)
│   │   ├── ProductDefinitions [M]   -- GAMEPASS_ID_HERE / PRODUCT_ID_HERE
│   │   ├── BadgeDefinitions [M]     -- BADGE_ID_HERE
│   │   └── Strings [M]              -- textos EN / PT-BR
│   ├── Modules [F]
│   │   ├── Net [M]                  -- camada única de Remotes (validação + rate limit)
│   │   │   ├── Server [M]           -- API do servidor (on / handle / fire / fireAll / fireList)
│   │   │   ├── Client [M]           -- API do cliente (fire / invoke / on)
│   │   │   └── T [M]                -- validadores de argumentos
│   │   ├── RemoteSchema [M]         -- lista de todos os Remotes e seus argumentos
│   │   ├── Loader [M]               -- ciclo de vida Init → Start de Services/Controllers
│   │   ├── RateLimiter [M]          -- limite de chamadas por jogador (token bucket)
│   │   ├── InstanceUtil [M]         -- WaitForChild com timeout, getOrCreate
│   │   ├── Signal [M]               -- eventos internos entre módulos
│   │   ├── Trove [M]                -- limpeza de conexões/instâncias
│   │   ├── Log [M]                  -- logs que respeitam DEBUG_MODE
│   │   ├── TableUtil [M]            -- deepCopy, reconcile, deepFreeze
│   │   ├── Rng [M]                  -- (Fase 4/6) RNG com seed por partida + sorteio ponderado
│   │   └── StateMachine [M]         -- (Fase 4) usado por Match, Entity e NPCs
│   └── Remotes [F]                  -- CRIADO AUTOMATICAMENTE pelo servidor (não criar à mão)
└── Assets [F]
    ├── Sounds [F]
    ├── UI [F]
    └── Effects [F]

ServerStorage                         -- NÃO replicado ao cliente (seguro, economiza memória)
├── Maps [F]
│   └── GasStation [Mdl]             -- mapa completo, clonado no início do turno
├── Entities [F]
│   └── Watcher [Mdl]                -- modelo da entidade
├── NPCs [F]                         -- modelos de clientes
└── EventAssets [F]                  -- modelos usados por eventos (inclusive secretos)

ServerScriptService
└── Server [F]
    ├── ServerMain [S]               -- ÚNICO Script do servidor: carrega os serviços
    ├── ServerDefinitions [F]        -- dados PRIVADOS (exploiters não leem)
    │   ├── EventDefinitions [M]     -- eventos, raridades, condições, segredos
    │   ├── EntityDefinitions [M]
    │   ├── NPCDefinitions [M]
    │   ├── DialogueDefinitions [M]
    │   ├── AdminConfig [M]          -- ADMIN_USER_IDS = {}
    │   └── DataConfig [M]           -- template dos dados salvos, backend, autosave
    ├── Data [F]                     -- backends de armazenamento usados pelo DataService
    │   └── MemoryBackend [M]        -- Fase 2 (DataStoreBackend na Fase 13)
    └── Services [F]                 -- todos são ModuleScripts com :Init() e :Start()
        ├── DataService [M]
        ├── PlayerService [M]
        ├── ProgressionService [M]
        ├── EconomyService [M]
        ├── InventoryService [M]
        ├── ShopService [M]
        ├── MonetizationService [M]
        ├── BadgeService [M]         -- (nome interno: AchievementService, ver nota)
        ├── LeaderboardService [M]
        ├── LobbyService [M]
        ├── MatchService [M]
        ├── ClockService [M]
        ├── MapService [M]
        ├── InteractionService [M]
        ├── TaskService [M]
        ├── DirectorService [M]
        ├── EventService [M]
        ├── TensionService [M]
        ├── EntityService [M]
        ├── NPCService [M]
        ├── DialogueService [M]
        ├── SecurityCameraService [M]
        ├── LightingService [M]
        ├── WeatherService [M]
        ├── AudioService [M]
        ├── SpectatorService [M]
        ├── RewardService [M]
        └── AdminService [M]

StarterPlayer
└── StarterPlayerScripts
    └── Client [F]
        ├── ClientMain [LS]          -- ÚNICO LocalScript: carrega os controllers
        ├── Controllers [F]          -- ModuleScripts com :Init() e :Start()
        │   ├── InputController [M]      -- detecta PC / toque / controle
        │   ├── InteractionController [M]
        │   ├── UIController [M]
        │   ├── HUDController [M]
        │   ├── LobbyController [M]
        │   ├── SecurityCameraController [M]
        │   ├── AudioController [M]
        │   ├── LightingController [M]   -- piscadas executadas localmente
        │   ├── WeatherController [M]
        │   ├── PerceptionController [M] -- efeitos que só este jogador vê/ouve
        │   ├── DialogueController [M]
        │   ├── SpectatorController [M]
        │   ├── SettingsController [M]
        │   └── DebugController [M]
        └── UI [F]
            ├── Theme [M]                -- cores, fontes, tamanhos
            ├── Components [F]           -- Button, Panel, ProgressBar, Toast…
            └── Screens [F]              -- HUD, Lobby, Shop, Inventory, Results, Settings…

StarterGui                           -- vazio ou quase: a UI é criada por código (ver nota)

Workspace
├── Lobby [F]                        -- lobby construído no Studio
└── Runtime [F]                      -- tudo que é criado durante a partida
    ├── ActiveMap                    -- clone de ServerStorage/Maps/<MapId>
    ├── NPCs
    └── Entities
```

### Notas sobre diferenças em relação à sua sugestão

1. **Serviços são ModuleScripts, não Scripts.** Um único `ServerMain` os carrega em ordem controlada (`Init` de todos → `Start` de todos). Isso elimina problemas de ordem de execução e dependências circulares.
2. **`ServerStorage` foi adicionado.** Mapas, entidade e assets de eventos secretos ficam lá. O cliente não recebe nada disso até ser necessário → mais seguro e menos memória no celular.
3. **Definições divididas em públicas e privadas.** Tudo em `ReplicatedStorage` pode ser lido por exploiters. Eventos secretos e condições ficam em `ServerScriptService`.
4. **Remotes criados por código** a partir do `RemoteSchema`. Você nunca cria RemoteEvents manualmente → sem nomes digitados errado, sem Remotes espalhados.
5. **UI criada por código** (componentes reutilizáveis + tema). É mais fácil manter consistência visual e responsividade PC/celular/console, e o código fica versionado. Elementos muito visuais podem ser feitos no Studio e apenas controlados pelo código.
6. **`CameraService` → `SecurityCameraService`.** "Camera" no Roblox já significa a câmera do jogador; o nome evita confusão.
7. **Serviços novos**: `DirectorService` (ritmo), `TensionService`, `ClockService`, `MapService`, `InteractionService`, `LightingService`, `AudioService`, `SpectatorService`, `RewardService`, `AdminService`, `LobbyService`, `ProgressionService`, `DialogueService`, `LeaderboardService`.
8. **`Random` → `Rng`**: `Random` já é uma classe nativa do Luau. `Rng` e `StateMachine` serão criados quando o primeiro sistema precisar deles (Fases 4 e 6), para não entregar código sem uso.
9. **Nome `BadgeService`** colide com o serviço nativo do Roblox. O módulo será chamado **`AchievementService`** (lida com badges nativas + conquistas internas). Os nomes da árvore acima valem com essa troca.

---

## 4. Sistemas e responsabilidades

### Núcleo
| Sistema | Responsabilidade |
|---|---|
| **ServerMain / ClientMain** | Carregar módulos, `Init` → `Start`, reportar falhas. |
| **Net + RemoteSchema** | Único ponto de comunicação. Cada Remote declara tipos de argumento, rate limit e se exige estado de partida. Servidor rejeita chamadas inválidas antes de chegarem ao serviço. |
| **Log / Debug** | `DEBUG_MODE` em `GameConfig`. Com debug desligado, nada aparece. Painel de debug só abre para admins validados no servidor. |

### Jogador e dados
| Sistema | Responsabilidade |
|---|---|
| **DataService** | Carregar/salvar perfil, session lock, autosave, retry, `BindToClose`, migração de schema. Única porta de escrita nos dados. |
| **PlayerService** | Ciclo de vida (entrou, carregou, saiu), personagem, spawn. |
| **ProgressionService** | XP, nível, estatísticas (ShiftsCompleted, Deaths, PlayTime…). |
| **EconomyService** | CASH e NIGHT TOKENS. Somente o servidor chama `AddCurrency`. |
| **InventoryService** | Itens possuídos, equipados, loadout. |
| **ShopService** | Compra de itens com moeda do jogo (validação de preço no servidor). |
| **MonetizationService** | GamePasses, Developer Products, `ProcessReceipt` idempotente. |
| **AchievementService** | Badges (IDs placeholder) + conquistas/descobertas internas. |
| **LeaderboardService** | OrderedDataStores, escrita no fim do turno, leitura em cache. |

### Partida
| Sistema | Responsabilidade |
|---|---|
| **LobbyService** | Criar turno, entrar, pronto, escolher mapa. |
| **MatchService** | Máquina de estados: `Lobby → Loading → Briefing → Shift → Climax → Results → Cleanup`. Lança via Local ou Teleport. |
| **MapService** | Clona o mapa, lê seus pontos padronizados (spawns, tarefas, câmeras, luzes, portas, nós de NPC/entidade). |
| **ClockService** | Relógio 04:00 → 05:00 (configurável). Emite "minuto mudou" e horários especiais (04:17, 04:33, 04:44). |
| **SpectatorService** | Morte → espectador das pessoas vivas da equipe, sem câmera livre que revele segredos. |
| **RewardService** | Calcula recompensas no servidor ao fim do turno e envia o resumo para a tela de resultados. |

### Gameplay
| Sistema | Responsabilidade |
|---|---|
| **InteractionService** | Registra objetos com tag `Interactable` (CollectionService) e cria ProximityPrompts. Valida distância, cooldown, estado e permissões. Encaminha para o sistema dono do objeto (tarefa, porta, telefone, câmera, NPC…). |
| **TaskService** | Sorteia tarefas da partida, acompanha progresso, valida conclusão (tempo de interação medido no servidor). |
| **DirectorService** | "Cérebro" do ritmo: orçamento de tensão por fase, decide quando o `EventService` pode disparar algo e quando a entidade pode agir. É o que impede o jogo de virar spam de jumpscare. |
| **EventService** | Seleciona eventos por raridade/peso/condições/cooldown, executa efeitos, registra descobertas. |
| **TensionService** | Tensão interna por jogador (0–100), calculada ~1x por segundo no servidor. Replicada como atributo; o cliente só aplica efeitos. |
| **EntityService** | Máquina de estados da entidade: `Dormant → Watching → Stalking → Manifest → Hunt → Retreat`. |
| **NPCService / DialogueService** | Clientes com rotas por nós pré-colocados (sem pathfinding pesado), diálogos curtos com escolhas. |
| **SecurityCameraService** | Lista de câmeras do mapa, quem está assistindo, anomalias exclusivas das câmeras. |
| **LightingService / WeatherService / AudioService** | Servidor decide *o quê* e *quando*; o cliente executa o efeito (piscar, trovão, som) localmente, com seed compartilhada quando todos devem ver igual. |

### Admin
| Sistema | Responsabilidade |
|---|---|
| **AdminService** | Comandos (disparar evento, dar moeda, teleportar, resetar partida, ver logs). Autorização **somente** por `ADMIN_USER_IDS` no servidor. |

---

## 5. Ordem de desenvolvimento

Mantemos suas 21 fases, com **um ajuste**:

> **Na Fase 2 criamos o `DataService` com a API final, mas guardando dados só em memória.** A Fase 13 troca o armazenamento por DataStore real sem mudar a API.
> Motivo: Progressão (12), Economia e Recompensas dependem de "onde ficam os dados do jogador". Sem isso, teríamos que reescrever esses sistemas depois.

| Fase | Entrega | Depende de |
|---|---|---|
| 1 Arquitetura base ✅ | Pastas, ServerMain, ClientMain, Loader, Net, RemoteSchema, RateLimiter, InstanceUtil, Log, Signal, Trove, GameConfig, Strings, Theme, AdminConfig, AdminService (autorização), DebugController | — |
| 2 Jogadores ✅ | PlayerService, DataService (memória), DataConfig, MemoryBackend, TableUtil, InputController | 1 |
| 3 Lobby | LobbyService, LobbyController, UI do lobby | 1, 2 |
| 4 Partida | MatchService, MapService, ClockService, HUD básico | 3 |
| 5 Interação | InteractionService, InteractionController (PC/celular/controle) | 1, 4 |
| 6 Tarefas | TaskService, TaskDefinitions, objetivo no HUD | 5 |
| 7 Primeiro mapa | Posto de gasolina com pontos padronizados | 4, 5, 6 |
| 8 Eventos | DirectorService, EventService, TensionService, PerceptionController | 4, 7 |
| 9 Áudio/iluminação | AudioService/Controller, LightingService/Controller, WeatherService | 8 |
| 10 NPCs | NPCService, DialogueService | 5, 8 |
| 11 Entidade | EntityService, SpectatorService (morte) | 8, 9 |
| 12 Progressão | ProgressionService, EconomyService, RewardService, tela de resultados | 2, 4 |
| 13 DataStore | DataService persistente | 2, 12 |
| 14 Inventário | InventoryService | 13 |
| 15 Loja | ShopService | 14 |
| 16 Monetização | MonetizationService, ProductDefinitions | 13, 15 |
| 17 UI final | Todas as telas no tema final | tudo acima |
| 18–21 | Polimento, otimização, testes, publicação (Teleport, badges, IDs reais) | tudo acima |

`SecurityCameraService` entra na Fase 8 (eventos de câmera dependem dele) e `AchievementService`/`LeaderboardService` na Fase 13.

### Grafo de dependências (resumo)

```
Net ─┬─> todos os serviços que falam com o cliente
     │
DataService ─> ProgressionService ─> RewardService
            ├> EconomyService ─> ShopService ─> MonetizationService
            └> InventoryService

LobbyService ─> MatchService ─> MapService
                            ├> ClockService ─> DirectorService
                            └> SpectatorService

InteractionService ─> TaskService
                   ├> SecurityCameraService
                   ├> NPCService ─> DialogueService
                   └> (portas, telefone, interruptores…)

DirectorService ─> EventService ─> LightingService / AudioService / WeatherService
               └> EntityService   └> PerceptionController (cliente)
TensionService <──> DirectorService
```

---

## 6. Riscos técnicos

| Risco | Mitigação |
|---|---|
| Recursos que **não funcionam no Studio** (Teleport, badges reais, alguns comportamentos de DataStore) | Modo `Local`; DataService com fallback em memória; indicar sempre "isto precisa do jogo publicado". |
| DataStore no Studio exige *Game Settings → Security → Enable Studio Access to API Services* e o jogo publicado | Instruções passo a passo na Fase 13. |
| Erros de copiar/colar para iniciante | Rojo (Decisão B); cada módulo valida dependências e dá erro claro com o nome do que falta. |
| `WaitForChild` infinito travando scripts | Wrapper com timeout + mensagem clara. |
| Eventos repetitivos após 10 partidas | Director + seed + pesos dinâmicos (eventos já vistos na partida perdem peso) + variações por evento. |
| Entidade injusta ou chata | Estados com limites de tempo, *cooldown* de caça, distância mínima, só caça sob condições específicas. |
| Escopo muito grande | Fases fechadas, MVP definido, nada fora da fase atual. |

## 7. Riscos de performance

| Risco | Mitigação |
|---|---|
| Muitas luzes com sombra (PointLight/SpotLight) | `Shadows` só nas luzes principais; luzes agrupadas por zona; piscar feito no cliente (sem replicar dezenas de mudanças). |
| NPCs com Humanoid e Pathfinding | Máximo 2–3 NPCs simultâneos; rotas por nós pré-definidos; Pathfinding só para a entidade e apenas no estado `Hunt`. |
| Loops por frame (`RunService.Heartbeat`) | Tensão e Director a ~1 Hz; lógica por eventos (sinais), não por *polling*. |
| Câmeras de segurança com ViewportFrame | Não usar ViewportFrame: trocar a câmera do jogador para o ponto da câmera (custo quase zero). |
| Chuva / partículas | Emissor só perto da câmera do jogador; opção "efeitos reduzidos". |
| Sons criados e destruídos toda hora | Pool de sons reaproveitados no AudioController. |
| Memória no celular | Mapas em ServerStorage; clonar só o mapa ativo; texturas moderadas; StreamingEnabled avaliado na Fase 19 (mapa pequeno, desligado no MVP para simplificar referências). |
| Limites de DataStore | Autosave a cada ~3 min, salvar ao sair, leaderboards escritos só no fim do turno e lidos com cache. |

## 8. Riscos de segurança

| Risco | Mitigação |
|---|---|
| Cliente enviando "me dê CASH" | Não existe nenhum Remote que receba valores de recompensa. O cliente só envia **intenções** ("quero interagir com o objeto X"). |
| Spam de Remotes | Rate limit por jogador e por Remote no `Net`; excesso é descartado e registrado. |
| Argumentos inválidos (tipos, NaN, instâncias falsas) | `RemoteSchema` valida tipo, intervalo e se a instância existe e pertence ao mapa ativo. |
| Completar tarefa à distância / instantaneamente | Servidor mede início e fim da interação, confere distância durante o processo e o estado da tarefa. |
| Recompensa duplicada | Recompensas calculadas uma única vez por partida por jogador (flag no servidor). |
| Compra falsa / duplicada | Apenas `ProcessReceipt` concede produtos; `PurchaseId` salvo no perfil na mesma operação; retorna `PurchaseGranted` só depois de salvar. |
| Duplicação de itens entre servidores | Session lock no DataService. |
| Admin falso | `ADMIN_USER_IDS` só no servidor; todo comando revalida o `UserId`. |
| Datamining de segredos | Definições/condições de eventos secretos no servidor. Observação honesta: assets que o cliente precisa exibir acabam sendo visíveis a quem investiga os arquivos — por isso o segredo está nas **condições**, não no modelo. |
| Espectador revelando informações | Espectador só vê o que as pessoas vivas veem; sem câmera livre pelo mapa; eventos perceptivos não são enviados a espectadores. |
| Teleporte inválido (exploit de movimento) | Checagens de posição nas interações e verificação simples de velocidade/teleporte no PlayerService. |

---

## 9. MVP

| Item | Conteúdo no MVP |
|---|---|
| Lobby | Lobby simples: Play, criar/entrar em turno, pronto. |
| Partida | Modo `Local`, 1–4 jogadores. |
| Mapa | Posto de gasolina (loja, caixa, estoque, banheiro, escritório, gerador, bombas, estacionamento, estrada, floresta). |
| Relógio | 04:00 → 05:00 em ~15 min reais (1 minuto do jogo ≈ 15 s). Horários especiais 04:17, 04:33, 04:44. |
| 5 tarefas | Abastecer o gerador · Repor prateleiras · Recolher o lixo · Verificar as câmeras · Conferir as bombas. |
| 10 eventos | Luzes piscando · Porta aberta · Produto cai · Telefone toca · Passos (perceptivo) · Barulho no estoque · Blackout · Portas batendo · Objeto de tarefa desaparece · Figura na câmera. Mais 1 variante **SECRET** do telefone às 04:44. |
| 1 entidade | "Watcher" (nome final a definir): observa, aparece de relance, mexe em luzes/portas, aparece nas câmeras, caça apenas no clímax ou sob condições raras. |
| Morte | Espectador da equipe. |
| Recompensas | XP + CASH por tarefa, conclusão e sobrevivência; tela SHIFT COMPLETE. |
| Salvamento | Nível, XP, CASH, estatísticas, eventos descobertos. |
| Fora do MVP | NPCs/diálogos, loja, inventário, monetização, clima variado, leaderboards, múltiplos mapas. |

Fluxo de construção do MVP: Fases 1 → 9, 11, 12, 13 (a Fase 10 – NPCs – fica para logo após o MVP, já que não está na lista do MVP).

---

## 10. Regras de código (valem para todas as fases)

1. Servidor tem **um** Script (`ServerMain`); cliente tem **um** LocalScript (`ClientMain`). Todo o resto é ModuleScript.
2. Services/Controllers expõem `Init()` (não espera, não chama outros módulos; registra handlers de Remotes) e `Start()` (pode esperar e usar outros módulos).
3. Remotes só existem no `RemoteSchema`. Todo Remote cliente → servidor tem `RateLimit` e `Args`.
4. O cliente só envia **intenções**. Valores (moeda, XP, progresso) nunca vêm do cliente.
5. Nada de `WaitForChild` sem timeout: use `InstanceUtil.waitForChild`.
6. Texto exibido ao jogador vem de `Strings`; cores/fontes vêm de `Theme`.
7. Logs via `Log.new("Nome")`; `:Debug` só aparece com `DEBUG_MODE`.
8. Formatação: StyLua (`stylua src`). Checagem de tipos: luau-lsp (`--!strict` em todos os arquivos).

---

## 11. Contratos entre sistemas (Fase 2)

- **Dados do jogador**: só o `DataService` escreve (`Set`, `Update`, `Increment`, `IncrementStat`). `Get` devolve cópia.
  Campos em `DataConfig.PUBLIC_ATTRIBUTES` (Level, XP, Cash, NightTokens) viram atributos do `Player`, que o cliente lê.
- **Ciclo de vida**: serviços usam `PlayerService.PlayerReady` / `PlayerService.PlayerLeaving`, nunca `Players.PlayerAdded` direto.
  Atributos do Player: `Ready` (boolean) e `State` (`Loading` | `Lobby` | `InShift` | `Spectating`).
- **Entrada**: controllers usam `InputController:BindAction(nome, { Keyboard, Gamepad }, fn)` e `InputController.InputTypeChanged`.

## 12. Testes automatizados

`tests/` contém um simulador do Roblox (Lune) que roda o código real de `src/` com 1 servidor + N clientes,
Remotes simulados e atributos replicados. Cada fase tem seu arquivo em `tests/specs/`, espelhando os TESTES 1/2/3 do guia.
Rodar tudo: `./scripts/check.sh` (formatação + tipos + testes + build do place).
Limites: o simulador não renderiza, não tem física e não reproduz o DataStore real; o teste final continua sendo no Studio.
