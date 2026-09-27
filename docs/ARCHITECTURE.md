# NIGHT SHIFT: 4AM — Arquitetura

> Documento-fonte da arquitetura. Toda funcionalidade nova segue os nomes e contratos daqui.
> Se algo mudar, este arquivo é atualizado junto com o código.

**Status:** Fases 1–21 implementadas (versão 0.21.0). 132 testes automatizados passando.
**Decisões:** A = modo Local no Studio / Teleport na publicação · B = Rojo · C = DataService próprio (UpdateAsync + trava de sessão) · D = EN + PT-BR.

---

## 1. Princípios

| Princípio | Como aparece no código |
|---|---|
| Servidor manda | O cliente só envia **intenções** (interagir, comprar item X, escolher resposta 2). Valores (moeda, XP, progresso) nunca vêm do cliente. |
| Um Script por lado | `ServerMain` (servidor) e `ClientMain` (cliente). Todo o resto é ModuleScript com `Init()` e `Start()`. |
| Remotes centralizados | `RemoteSchema` lista todos. `Net` cria, valida tipos, aplica limite de chamadas. |
| Dados orientados a definição | Tarefas, eventos, NPCs, diálogos, itens, sons, badges, produtos, mapas: tudo em ModuleScripts de definição. |
| Segredos no servidor | Eventos, NPCs, diálogos, entidade e ritmo ficam em `ServerScriptService` (exploiters não leem). |
| Ritmo controlado | `DirectorService` decide **quando**; `EventService` decide **o quê**. |
| Percepção individual | Efeitos só para um jogador vão pelo Remote `Perception`. |

## 2. Estrutura

```
ReplicatedStorage
├── Shared                        (Rojo: src/shared)
│   ├── Config        GameConfig · MatchConfig · TaskConfig · EconomyConfig · InteractionConfig
│   ├── Definitions   Strings · MapDefinitions · TaskDefinitions · ItemDefinitions · ProductDefinitions
│   │                 BadgeDefinitions · SoundDefinitions · SettingsDefinitions · DocumentDefinitions
│   ├── Modules       Net(Server/Client/T) · RemoteSchema · Loader · Log · Signal · Trove · RateLimiter
│   │                 InstanceUtil · TableUtil · Rng · StateMachine · GameClock · FigureFactory
│   └── Remotes       (criado pelo servidor em tempo de execução)
├── MatchState        (Folder criado pelo MatchService — atributos públicos da partida)
└── LightingState     (Folder criado pelo LightingService — estado das luzes e clima)

ServerStorage
└── Maps/GasStation   (gerado a partir do GasStationBuilder; pode ser editado à mão)

ServerScriptService/Server        (Rojo: src/server)
├── ServerMain (Script)
├── ServerDefinitions  AdminConfig · DataConfig · EventDefinitions · DirectorConfig · TensionConfig
│                      EntityDefinitions · NPCDefinitions · DialogueDefinitions
├── Services           (33 serviços — ver §3)
├── Events             (1 ModuleScript por evento: Run / CanRun)
├── Data               MemoryBackend · DataStoreBackend
├── Match              TeleportLauncher
└── World              LobbyBuilder · GasStationBuilder · NPCBuilder · PlaceholderMapBuilder

StarterPlayerScripts/Client       (Rojo: src/client)
├── ClientMain (LocalScript)
├── Controllers        (19 controllers — ver §4)
└── UI                 Theme · Components · Screens (Lobby, HUD, Results) · Panels (Shop, Inventory,
                       Leaderboard, Settings, PanelKit)

Workspace
├── Lobby              (gerado pelo LobbyBuilder se você não criar um)
└── Runtime/ActiveMap  (mapa clonado durante o turno)
```

## 3. Serviços (servidor)

| Grupo | Serviço | Responsabilidade |
|---|---|---|
| Núcleo | AdminService | Quem é admin (só servidor), comandos de admin, info de debug |
| Jogador | PlayerService | Ciclo de vida, estado (`Loading/Lobby/InShift/Spectating`), perfil público |
| | DataService | Única porta dos dados; backend Memory/DataStore; autosave; `SaveNow` |
| | SettingsService | Configurações validadas e salvas |
| Lobby/partida | LobbyService | Grupos (turnos), pronto, iniciar |
| | MatchService | Fases `Idle→Loading→Briefing→Shift→Results→Cleanup`; modo Local/Lobby/Shift |
| | MapService | Carrega mapa, zonas, spawns, pastas padrão |
| | ClockService | 04:00→05:00, horários especiais 04:17/04:33/04:44 |
| Jogo | InteractionService | Sistema único de interação (ProximityPrompt + validação) |
| | DoorService | Portas (abrir, bater, trancar) |
| | TaskService | Tarefas sorteadas, passos, recompensas por equipe |
| | DirectorService | Ritmo do terror |
| | EventService | 17 eventos + 5 descobertas, raridades, telefone, descobertas |
| | TensionService | Tensão por jogador, sons falsos |
| | EntityService | Entidade: Watching/Stalking/Manifest/Hunt, temperamentos |
| | SpectatorService | Morte e espectador |
| | NPCService / DialogueService | Clientes e conversas |
| | DocumentService | Documentos da história |
| | SecurityCameraService | Monitor de câmeras, anomalias só nas câmeras |
| Ambiente | LightingService · WeatherService · AudioService | Luz por zona, clima, sons |
| Progressão | EconomyService · ProgressionService · RewardService | CASH/Tokens, XP/nível, recompensas |
| Itens | InventoryService · ShopService · CosmeticService · FlashlightService | Itens, loja, visual, lanterna |
| Loja real | MonetizationService | VIP (GamePass), Tokens (Dev Products), ProcessReceipt |
| Meta | AchievementService · LeaderboardService | Conquistas/badges, rankings |

## 4. Controllers (cliente)

Input · Interaction · Notification · Lobby · HUD · Results · Audio · Lighting · Weather · Perception ·
SecurityCamera · Dialogue · Document · Spectator · Flashlight · Settings · Chat · Debug · Admin.

## 5. Contratos entre sistemas

- **Dados:** só o `DataService` escreve (`Set`, `Update`, `Increment`, `IncrementStat`, `SaveNow`). `Get` devolve cópia.
  Atributos públicos no Player: `Level`, `XP`, `Cash`, `NightTokens`, `Ready`, `State`, `Tension`, `VIP`, `FlashlightOn`.
- **Ciclo de vida:** use `PlayerService.PlayerReady/PlayerLeaving`, nunca `Players.PlayerAdded` direto.
- **Partida:** `MatchService.MatchStarted(match)`, `MatchEnded(match, result)`, `GetAlivePlayers()`, `IsAlive()`, `MarkDead()`.
- **Interação:** objeto com tag `Interactable` + atributo `InteractionType`; o dono registra
  `InteractionService:RegisterHandler(tipo, { CanInteract?, OnInteract })`.
  Tipos atuais: `Door`, `Task`, `Phone`, `SecurityMonitor`, `LightSwitch`, `Document`, `NPC`.
- **Eventos:** módulo em `Server/Events/<Id>` com `Run(ctx)`/`CanRun(ctx)`; `ctx` traz `Players` (vivos), `Target`,
  `Rng`, `Services`, `Witness/WitnessNear/WitnessZone/WitnessAll`, `Perceive`, `IsActive`.
- **Luz:** estado por zona em `ReplicatedStorage.LightingState` (`Zone_<Nome>`, `Blackout`, `Weather`); o cliente aplica.
- **Mapa:** `Model <MapId>` com `Spawns`, `Zones`, `SecurityCameras`, `EventAnchors`, `EntityNodes`, `NPCPath`, `Doors`.
- **UI:** telas só desenham e repassam ações; controllers falam com o servidor; textos via `Strings`.

## 6. Segurança

- Todo Remote cliente→servidor tem `RateLimit` e validação de tipo (NaN/infinito barrados).
- Interação: distância, tempo segurando, cooldown, estado do jogador, objeto no mundo.
- Tarefas, recompensas e compras calculadas só no servidor; recompensa 1x por partida.
- `ProcessReceipt` idempotente (`Purchases[PurchaseId]`), `PurchaseGranted` só depois de salvar.
- DataStore com trava de sessão (sem duplicação entre servidores) e novas tentativas.
- Admin: `ADMIN_USER_IDS` no servidor; toda ação revalidada.
- Espectador: sem câmera livre; não recebe eventos perceptivos.

## 7. Performance

- Um Script por lado; loops de servidor a 1 Hz (tensão), por minuto do jogo (diretor, NPCs, entidade) e 7–10 Hz só
  enquanto NPC/entidade se movem (sem Humanoid, sem física; Pathfinding só na caçada).
- Piscadas de luz, chuva, estática e efeitos de tensão rodam no cliente.
- Sons posicionais reaproveitam 12 emissores.
- Mapas ficam no ServerStorage até o turno começar. `StreamingEnabled` desligado (mapa pequeno); revisar em mapas grandes.

## 7.1 Testes

`tests/` tem um simulador do Roblox (Lune) que roda o código real com 1 servidor + N clientes, Remotes, atributos,
tags, prompts, DataStore e Marketplace simulados. `./scripts/check.sh` roda formatação, tipos, testes e gera o place.
Limites: sem física, sem renderização, sem rede real — o teste visual final é no Studio.

## 8. Como adicionar conteúdo

| Quero adicionar | Onde |
|---|---|
| Tarefa | `TaskDefinitions` + pontos no mapa (`InteractionType=Task`, `TaskId`, `Point`) + textos |
| Evento | `ServerDefinitions/EventDefinitions` + `Server/Events/<Id>.luau` + `EVENT_NAME_<Id>` |
| Cliente (NPC) | `NPCDefinitions` + `DialogueDefinitions` + textos |
| Item | `ItemDefinitions` + `ITEM_<Id>` |
| Som | `SoundDefinitions` (SoundId) |
| Mapa | `MapDefinitions` + `ServerStorage/Maps/<Id>` (ou um Builder em `World/`) |
| Conquista | `BadgeDefinitions` + textos |
