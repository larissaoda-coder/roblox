# Art Películas — sistema web

Aplicação web da Art Películas para **simular películas automotivas**, **gerar orçamentos** e **gerenciar clientes, serviços e equipe**. Frontend em React + TypeScript + Tailwind CSS; backend no Supabase (PostgreSQL, Auth, Storage e Edge Functions).

## Módulos

| Módulo | O que faz |
|---|---|
| Página inicial e login | Apresentação, login com validação, mostrar/ocultar senha, recuperação de senha por e-mail, convite com definição de senha |
| Visão geral | Indicadores reais do banco: clientes, orçamentos pendentes, serviços, simulações, orçamentos e simulações recentes, próximos serviços |
| Garagem de veículos | Biblioteca com 59 modelos populares no Brasil (marca, modelo, geração, anos, categoria), busca e filtros, cadastro, imagens autorizadas com origem obrigatória, editor de máscaras dos vidros, modelo 3D (.glb) com mapeamento das malhas de vidro, películas indicadas por veículo |
| Simulador de insulfilm | Película por vidro (para-brisa, dianteiros, traseiros, vidro traseiro principal), níveis de transmissão, comparação antes/depois, alerta de referência legal, salvar simulação e gerar orçamento |
| Catálogo de películas | Nome, fabricante, linha, transmissão luminosa (VLT), características técnicas informadas pelo administrador, preço e unidade |
| Clientes | Cadastro com validação de CPF/CNPJ (inclusive CNPJ alfanumérico), busca, histórico de orçamentos, serviços e simulações |
| Orçamentos | Itens de película/serviço/outros, descontos por item e geral com limite autorizado, validade, observações, status com linha do tempo, impressão A4 |
| Serviços | Ordens de serviço (agenda, responsável, situação) e tipos de serviço |
| Histórico | Registro automático de alterações: quem, quando e o que mudou |
| Usuários e permissões | Convite por e-mail ou senha inicial, papéis, ativar/desativar contas, matriz de permissões editável |
| Configurações | Perfil, troca de senha, dados da empresa, logotipo, validade padrão, limite de desconto e referências legais do simulador |

### Como a simulação funciona

- **Imagem com máscaras:** o administrador envia uma foto autorizada do veículo e desenha os polígonos de cada vidro. O simulador escurece **somente** essas áreas (camada de multiplicação com bordas suavizadas), sem alterar a carroceria.
- **Modelo 3D:** com um arquivo `.glb` do próprio veículo, as malhas de vidro são associadas às zonas (com sugestão automática pelo nome) e os materiais são alterados em tempo real; o modo comparar renderiza o original e a simulação lado a lado.
- **Referência genérica:** quando o veículo ainda não tem mídia, é usado um modelo 3D genérico da categoria (hatch, sedã, SUV, picape), **sempre identificado como genérico** na tela.

Nenhuma foto ou modelo 3D de veículo é distribuído com o sistema: as mídias devem ser cadastradas com origem e autorização informadas.

## Arquitetura

```
art-peliculas/
├── src/
│   ├── auth/                 # Sessão, perfil, permissões e rotas protegidas
│   ├── components/
│   │   ├── layout/           # AppLayout (menu lateral + cabeçalho), layout público, logo
│   │   └── ui/               # Botões, campos, cartões, tabelas, modais, notificações…
│   ├── features/             # Páginas e acesso a dados por módulo
│   │   ├── dashboard/  vehicles/  simulator/  three/  films/  customers/
│   │   ├── quotes/  services/  history/  users/  settings/  auth/  landing/
│   └── lib/                  # Cliente Supabase, formatação, validação, cálculo de orçamento…
├── supabase/
│   ├── migrations/           # Esquema, RLS, auditoria, regras de orçamento, storage, biblioteca de veículos
│   ├── functions/admin-users # Edge Function de administração de usuários
│   ├── templates/            # E-mails de convite e recuperação em português
│   └── config.toml           # Configuração para `supabase start`
├── scripts/create-admin.mjs  # Cria/promove o primeiro administrador
└── tests/                    # Integração (segurança e regras) e E2E (Playwright)
```

### Segurança

- Autenticação real pelo Supabase Auth (senhas com hash no servidor; nada de credenciais no frontend).
- O frontend usa apenas a **chave pública**; a `service_role` fica somente na Edge Function e no script de administrador.
- **RLS em todas as tabelas**: visitantes não leem nada; usuários inativos não leem nem gravam; escritas exigem a permissão do papel (`public.has_permission`).
- Orçamentos e itens só são gravados pelas funções `save_quote` e `set_quote_status`, que recalculam totais e validam o **limite de desconto** no servidor.
- Validações no banco (CPF/CNPJ, placas, e-mail, faixas numéricas, máscaras e configurações de simulação).
- Histórico gravado por gatilhos (`audit_log`), sem permissão de escrita para usuários.
- Bucket de mídia privado com políticas por pasta (`vehicles/`, `models/`, `branding/`) e URLs assinadas.
- Proteções de conta: ninguém altera o próprio papel, desativa a própria conta ou remove o último administrador ativo; contas desativadas são bloqueadas no login.

### Papéis e permissões padrão

| Permissão | Admin | Gerente | Vendedor | Instalador |
|---|:-:|:-:|:-:|:-:|
| Gerenciar garagem / películas | ✔ | ✔ | | |
| Cadastrar e editar clientes | ✔ | ✔ | ✔ | |
| Excluir clientes | ✔ | ✔ | | |
| Criar e editar orçamentos | ✔ | ✔ | ✔ | |
| Autorizar desconto acima do limite / excluir orçamentos | ✔ | ✔ | | |
| Gerenciar serviços | ✔ | ✔ | ✔ | ✔ |
| Histórico e configurações | ✔ | ✔ | | |
| Usuários e permissões | ✔ | | | |

A matriz pode ser ajustada em **Usuários e permissões** (o administrador sempre tem acesso total).

## Configuração em produção

Pré-requisitos: Node.js 20+, uma conta no [Supabase](https://supabase.com) e o [Supabase CLI](https://supabase.com/docs/guides/cli).

1. **Crie o projeto** no Supabase e anote `Project URL`, a chave pública (`anon`/`publishable`) e a `service_role` (Project Settings → API).
2. **Aplique o banco** (esquema, políticas, funções, storage e biblioteca de veículos):
   ```bash
   supabase link --project-ref SEU_PROJECT_REF
   supabase db push
   ```
3. **Publique a Edge Function** de usuários:
   ```bash
   supabase functions deploy admin-users
   ```
   Ela usa as variáveis padrão `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY`, já disponíveis nas funções. Opcional: `supabase secrets set SITE_URL=https://seu-dominio`.
4. **Configure o Auth** (Authentication no painel):
   - *URL Configuration*: `Site URL` = endereço do sistema; em *Redirect URLs* adicione `https://seu-dominio/redefinir-senha`.
   - *Providers → Email*: desative **Allow new users to sign up** (as contas são criadas por convite).
   - *SMTP Settings*: configure um SMTP próprio (o SMTP padrão do Supabase tem limite baixo e é apenas para testes).
   - *Email Templates*: cole o conteúdo de `supabase/templates/invite.html` (Invite user) e `supabase/templates/recovery.html` (Reset password).
5. **Crie o primeiro administrador** (no seu computador):
   ```bash
   npm install
   SUPABASE_URL=https://SEU-PROJETO.supabase.co \
   SUPABASE_SERVICE_ROLE_KEY=sua-service-role-key \
   npm run create-admin -- admin@suaempresa.com.br "Senha-Forte-123" "Nome do Administrador"
   ```
   Alternativa: crie o usuário em *Authentication → Users* e execute no SQL Editor
   `update public.profiles set role = 'admin', active = true where email = 'admin@suaempresa.com.br';`
6. **Publique o frontend** (Vercel, Netlify ou outro host estático):
   - Variáveis: `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` (veja `.env.example`).
   - Build: `npm run build` → pasta `dist/`.
   - Já incluídos: `vercel.json` e `public/_redirects` (rotas da SPA).

### Primeiros passos no sistema

1. **Configurações** → dados da empresa, logotipo, validade dos orçamentos, limite de desconto e condições padrão.
2. **Catálogo de películas** → cadastre os produtos com os dados da ficha técnica do fabricante.
3. **Serviços → Tipos de serviço** → instalação, remoção etc., com preço base.
4. **Garagem** → em cada veículo, envie fotos autorizadas e desenhe as máscaras dos vidros (ou envie um modelo 3D licenciado e mapeie os vidros). Associe as películas indicadas.
5. **Usuários e permissões** → convide a equipe e ajuste as permissões.

## Desenvolvimento local

```bash
npm install
supabase start                 # sobe Postgres, Auth, Storage, Studio e caixa de e-mails (Docker)
supabase functions serve       # em outro terminal, para a Edge Function
cp .env.example .env.local     # preencha com a URL e a anon key exibidas pelo `supabase start`
npm run create-admin -- admin@local.test "Senha-Local-123" "Administrador"   # com SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY locais
npm run dev                    # http://localhost:5173
```

## Testes

| Comando | Cobertura |
|---|---|
| `npm run test:unit` | Validações (CPF/CNPJ, placas, senha), cálculo de orçamento e limite de desconto, formatação, geometria das máscaras, tingimento 3D, mensagens de erro |
| `npm run test:integration` | Contra um Supabase de desenvolvimento: RLS por papel, acesso anônimo, usuário inativo, regras de orçamento e status, desconto autorizado, histórico, storage, Edge Function, convite e recuperação de senha |
| `npm run test:e2e` | Playwright com o app em execução: login/recuperação, fluxo completo (película → cliente → veículo → imagem e máscaras → simulação → orçamento → status → ordem de serviço → impressão), modelo 3D, papéis/convite e responsividade (celular e tablet) |

Variáveis para integração/E2E (**use somente um projeto de desenvolvimento**): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` e `MAILPIT_URL` (caixa de e-mails local, ex.: `http://localhost:54324`). Os testes criam usuários e registros próprios.

Também: `npm run typecheck`, `npm run lint` e `npm run build`.

## Observações

- As referências de transmissão luminosa mínima (75% para-brisa, 70% vidros dianteiros, 28% demais vidros) são configuráveis e servem como alerta; a medição oficial considera o conjunto vidro + película e a legislação vigente deve ser conferida.
- A simulação é uma aproximação visual: iluminação, cor do vidro original e ângulo alteram a aparência real.
- Os dados técnicos das películas não são pré-cadastrados: devem ser informados pelo administrador conforme o fabricante.
