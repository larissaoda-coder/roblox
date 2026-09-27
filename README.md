# NIGHT SHIFT: 4AM

Horror cooperativo para Roblox. Arquitetura completa em [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Como o projeto funciona

- **Código** (`src/`) fica neste repositório e é sincronizado com o Roblox Studio pelo **Rojo**.
- **Mapas, modelos, sons e o lobby** são construídos direto no Studio e salvos no place.
- O Rojo só controla três pastas. **Não crie nada manualmente dentro delas**, porque o Rojo apaga:
  - `ReplicatedStorage > Shared`
  - `ServerScriptService > Server`
  - `StarterPlayer > StarterPlayerScripts > Client`

| Pasta no repositório | Onde aparece no Studio |
|---|---|
| `src/shared` | `ReplicatedStorage > Shared` |
| `src/server` | `ServerScriptService > Server` |
| `src/client` | `StarterPlayer > StarterPlayerScripts > Client` |

Tipo do objeto pelo nome do arquivo:

| Arquivo | Objeto no Studio |
|---|---|
| `Nome.server.luau` | Script |
| `Nome.client.luau` | LocalScript |
| `Nome.luau` | ModuleScript |
| `Pasta/init.luau` | ModuleScript chamado `Pasta` (os outros arquivos da pasta viram filhos dele) |

## Instalação (uma vez só)

1. Instale o [Visual Studio Code](https://code.visualstudio.com/).
2. Baixe este repositório (botão verde **Code > Download ZIP** no GitHub) e extraia em uma pasta.
3. No VS Code: **File > Open Folder** e escolha a pasta extraída.
4. No VS Code, abra a aba de extensões (ícone de quadradinhos, ou `Ctrl+Shift+X`), procure **Rojo** (autor: *evaera*) e instale.
5. Clique no ícone do Rojo na barra lateral. Se ele pedir para instalar o Rojo, aceite.
6. Ainda no menu do Rojo, escolha **Install Roblox Studio plugin**. Feche e reabra o Roblox Studio.

## Conectar ao Studio (toda vez que for trabalhar)

1. No VS Code, no menu do Rojo, clique em **default.project.json** para iniciar o servidor.
2. No Roblox Studio, abra o place do jogo.
   - Primeira vez: **File > Open from File** e escolha `NightShift.rbxlx` (já vem com baseplate e spawn).
   - Ou crie um novo **Baseplate**.
3. No Studio: aba **Plugins > Rojo > Connect**.
4. O código aparece nas três pastas acima. Toda alteração salva no VS Code aparece no Studio na hora.

Para gerar o place sem o VS Code: `rojo build place.project.json -o NightShift.rbxlx`.

## Verificação automática

`./scripts/check.sh` roda, em ordem:
1. Formatação (StyLua).
2. Checagem de tipos (luau-lsp).
3. Testes automatizados (Lune). O simulador em `tests/harness/` roda o código real com servidor + clientes simulados.
4. Build do place.

Ferramentas necessárias: rojo, stylua, luau-lsp e lune (veja `rokit.toml`).
