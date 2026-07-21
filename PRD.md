# PRD — `devc-debian-claude`: esqueleto de projeto com Devcontainer + Claude Code

> **Documento de produto (fonte de verdade) deste repositório.**
> Não confundir com o `.claude/PRD.md`, que é o PRD do *projeto-alvo* criado a partir deste kit
> (fica como esqueleto a preencher; não existe mais conteúdo de exemplo amarrado a um domínio).
>
> **Status:** RF1–RF6 (bootstrap) implementados e testados — `install.sh` e `install.ps1` já
> existem na raiz. Este documento continua sendo a fonte de verdade para a evolução do kit.

---

## 1. Visão geral e propósito

`devc-debian-claude` é um **template/esqueleto** para iniciar novos projetos já com um ambiente
de desenvolvimento padronizado: um **devcontainer Debian com Claude Code pré-instalado**, scripts
utilitários, um catálogo de plugins e uma trilha de subagentes `plan → run → test`.

**Problema original:** usar o template era um processo **manual e propenso a erro** — clonar o
repo, mover os arquivos (inclusive ocultos), trocar o nome no `devcontainer.json`, criar o `.env`,
apagar a pasta `.git` e rodar `git init`. Cada passo esquecido gerava um projeto novo "contaminado"
com metadados do template. Esse processo manual ainda é documentado no `README.md` como alternativa
para quem preferir não usar o instalador.

**Resultado esperado:** transformar esse processo em **um único comando**. O desenvolvedor executa
um script de bootstrap que baixa o kit, remove tudo que referencia *este* repositório, pergunta os
poucos dados que não podem vir de variáveis de ambiente e entrega um projeto novo pronto para abrir
no devcontainer.

O repositório continua evoluindo de forma independente: novos agentes, skills, plugins e melhorias
de infraestrutura são adicionados aqui e passam a beneficiar todos os projetos futuros.

---

## 2. Público-alvo e casos de uso

- **Público:** desenvolvedores (individuais ou times) que iniciam projetos novos e querem um
  ambiente Claude Code + Devcontainer consistente, sem reconstruir a base a cada vez.
- **Caso de uso principal:** "quero começar um projeto novo já com Claude Code, devcontainer
  Debian e a trilha de agentes, em um comando".
- **Caso de uso secundário:** evoluir o próprio template (adicionar agentes, skills, plugins,
  ajustar a infra) para que novos projetos herdem as melhorias.

---

## 3. Estado atual (baseline)

O que já existe no repositório:

### Raiz
- **`install.sh`** / **`install.ps1`** — bootstrap (RF1–RF6, ver §4). Removidos do projeto gerado
  após o uso (só fazem sentido no template).
- **`README.md`** — uso do template (bootstrap + estrutura + fluxo manual alternativo).
- **`CLAUDE.md`** — orientações do kit para o Claude Code (estrutura, ciclo de agentes, convenções).
- **`PRD.md`** — este documento. Removido do projeto gerado (é sobre o kit, não sobre o projeto-alvo).

### `.devcontainer/`
- **`Dockerfile`** — base `debian:bookworm-slim`; instala bash, git, curl, gnupg, sudo, xz-utils,
  **Node.js LTS + npm** e **google-chrome-stable** (para automação de navegador). Cria usuário
  não-root `app` (UID/GID 1000) com sudo NOPASSWD e pré-cria `/home/app/.claude`. O cabeçalho deixa
  claro que é infra de **desenvolvimento** (Dockerfile/compose de produção viriam na raiz).
- **`docker-compose.yml`** — service `app`; `image`, `container_name` e tag vindos do `.env`
  (`DOCKER_IMAGE_NAME`, `DOCKER_IMAGE_TAG`, `CONTAINER_NAME`); `TZ=America/Sao_Paulo`;
  volume `..:/workspace:cached`; `command: sleep infinity`.
- **`devcontainer.json`** — `name` e `description` (reescritos pelo instalador), usa o compose,
  feature oficial `ghcr.io/anthropics/devcontainer-features/claude-code:1.0`, volume nomeado
  persistente em `/home/app/.claude`, `CLAUDE_CONFIG_DIR` e locale UTF-8 (`LANG`/`LC_ALL=C.UTF-8`),
  `postCreateCommand: bash .devcontainer/postCreate.sh`.
- **`postCreate.sh`** — roda no pós-criação do container; contém um bloco marcado
  (`# >>> devc-debian-claude: plugins selecionados ... <<<`) onde o instalador insere os comandos
  dos plugins escolhidos no menu opcional (RF5). Vazio (só comentários) se nenhum foi escolhido.
- **`.env.example`** — `DOCKER_IMAGE_NAME`, `DOCKER_IMAGE_TAG`, `CONTAINER_NAME`.

### `scripts/`
- **`clean.sh`** — remove containers/volumes do devcontainer deste projeto, **preservando o volume
  compartilhado `vscode`**; suporta `-y/--force`.
- **`plugins.sh`** — **catálogo manual** (não roda automático) do que *pode* ser instalado:
  **agent-browser**, **Context7** (MCP) e **context-mode**. Política declarada: o usuário decide o
  que instalar para não poluir o container. É a fonte usada pelo menu opcional do instalador.

### `.claude/`
- **`agents/`** — 5 subagentes **genéricos** (RF4) formando o ciclo `plan → run → test` em duas
  trilhas (dev = código, ops = infra): `plan-dev`, `plan-ops`, `run-dev`, `run-ops`, `test-ops`.
  Sem amarração a um domínio específico; usam `.claude/PRD.md` do projeto gerado como fonte de
  verdade.
- **`plans/README.md`** — convenção de nomes de planos (`AAAA-MM-DD-{dev|ops}-<assunto>.md`).
- **`skills/README.md`** — ponto de extensão para skills do Claude Code (ainda sem skills reais).
- **`PRD.md`** — esqueleto genérico de PRD para o projeto-alvo (seções em branco + instruções),
  preenchido pelo desenvolvedor após o bootstrap. **Não** é removido pelo instalador — ao contrário
  do `PRD.md` da raiz, ele é o ponto de partida do novo projeto, não conteúdo específico do kit.
- **`settings.json`** — hooks de `Stop`/`Notification` (bell no terminal).

---

## 4. Requisitos funcionais

### RF1 — Script de bootstrap (downloader avulso), Linux + Windows
- Dois scripts com **paridade de funcionalidades**:
  - **`install.sh`** — Linux/macOS, invocável via `curl -fsSL <url>/install.sh | bash`.
  - **`install.ps1`** — Windows, invocável via `iwr <url>/install.ps1 | iex` (PowerShell).
- **Modelo downloader avulso:** o usuário **não** clona o repositório manualmente. O script é
  auto-suficiente e executa o fluxo completo:
  1. Baixar o kit (`git clone --depth 1` do repositório do template em diretório temporário).
  2. Materializar os arquivos no diretório de destino (inclusive arquivos ocultos).
  3. **Apagar o `.git` do template** (ver RF3).
  4. Coletar dados por prompt interativo (ver RF2).
  5. Reescrever os arquivos com os dados informados (ver RF2).
  6. Rodar `git init` no novo projeto.
  7. Oferecer o menu opcional de plugins (ver RF5) e finalizar com instruções de próximos passos
     (abrir no devcontainer / *Reopen in Container*).

### RF2 — Prompt interativo (dados que não vêm de env)
Alguns valores **não podem** ser preenchidos por variáveis de ambiente (notadamente o
`devcontainer.json`), por isso são coletados por prompt:
- **Nome do projeto**
- **Nome do devcontainer / container**
- **Descrição do projeto**

Reescrita direcionada a partir dessas respostas:
- **`.devcontainer/devcontainer.json`** — campos `name` e `description` (edição JSON real no
  PowerShell via `ConvertFrom-Json`/`ConvertTo-Json`; substituição literal do texto padrão no bash,
  já que o template controla o conteúdo exato de origem).
- **`.env`** — gerado a partir do `.env.example`, com `CONTAINER_NAME`/`DOCKER_IMAGE_NAME`
  derivados (slugificados) do nome do devcontainer informado, e `DOCKER_IMAGE_TAG` reiniciado
  em `0.1`.
- **`README.md`** — sobrescrito por um README novo e mínimo do projeto-alvo (nome + descrição +
  passos de devcontainer), no lugar do README do template.

### RF3 — Limpeza do que referencia *este* repositório
- Apaga o `.git` do template baixado (clonado em diretório temporário) antes de copiar os arquivos
  para o destino — o projeto gerado nunca chega a ter o `.git` do template.
- Remove da raiz do projeto gerado o que só faz sentido no kit: `PRD.md` (este documento),
  `install.sh` e `install.ps1`.
- **Não** remove o restante (devcontainer, scripts, agentes genéricos, settings, `.claude/PRD.md`).
- O script nunca apaga o `.git` de um repositório que não seja o clone temporário do template.

### RF4 — Agentes e PRD genéricos
- Os 5 agentes são **genéricos e reutilizáveis** (sem amarração a um domínio) — implementado.
- `.claude/PRD.md` deixou de ser conteúdo de exemplo amarrado a um domínio e passou a ser um
  **esqueleto genérico** (seções em branco + instruções) para o projeto-alvo preencher. Por ser um
  ponto de partida útil (não mais um "exemplo" a limpar), o instalador **mantém** esse arquivo —
  só remove o `PRD.md` da raiz, que é sobre o kit em si.

### RF5 — Menu opcional de plugins
- Durante a instalação, oferecer um **menu opcional** com os plugins do `scripts/plugins.sh`
  (agent-browser, Context7, context-mode) para o usuário escolher quais instalar.
- **Default: nenhum**, preservando a política de container enxuto. `plugins.sh` continua servindo
  como catálogo para instalação manual posterior.

### RF6 — Idempotência e segurança
- Confirmar antes de sobrescrever; **abortar se o diretório de destino não estiver limpo**, a menos
  que `-y`/`--force`/`--yes` (bash) ou `-Yes` (PowerShell) seja passado.
- Operações destrutivas (remoção do `.git` do template, remoção do `PRD.md`/`install.*` da raiz)
  restritas ao clone temporário / ao diretório recém-criado do projeto.
- Mensagens claras a cada passo e falha segura (parar na primeira condição inesperada).
- **Testado:** diretório não vazio sem `--force`/`-Yes` aborta (exit ≠ 0) tanto no bash quanto no
  PowerShell; com o flag, prossegue com aviso.

---

## 5. Requisitos não-funcionais

- **Portabilidade:** `install.sh` em bash puro (única dependência externa: `git`); `install.ps1`
  em PowerShell nativo (`Get-Command git`), usando `ConvertFrom-Json`/`ConvertTo-Json` em vez de
  regex para editar o `devcontainer.json` — mais robusto que a substituição literal usada no bash.
- **Modo não-interativo:** flags (`--name`/`--container`/`--description` no bash; `-Name`/
  `-ContainerName`/`-Description` no PowerShell) ou variáveis de ambiente (`INSTALL_*`, necessárias
  no PowerShell ao usar `irm | iex`, que não aceita parâmetros de linha de comando). Sem terminal
  disponível e sem esses valores, o script usa padrões sensatos com aviso, em vez de travar.
- **Robustez de terminal (lição aprendida na validação):** `curl | bash` deixa `stdin` ocupado pelo
  pipe; checar `[[ -r /dev/tty ]]` não é suficiente (o arquivo existe mas abrir para leitura falha
  com ENXIO em ambientes sem terminal controlador) — o bash usa uma função `tty_available()` que
  tenta abrir o descritor de verdade antes de decidir se prompta. No PowerShell, `$null -notmatch
  <regex>` **não** retorna `$false` como se esperaria — a checagem de diretório não vazio precisa
  do cast explícito `[string]$reply` antes de comparar, senão a confirmação de segurança passa
  aberta silenciosamente quando `Read-Host` recebe EOF. Ambos os casos foram encontrados e
  corrigidos durante os testes deste PRD.
- **Acentuação/locale:** tratar corretamente caracteres como `ç` e `'` (testado em ambos os
  scripts); o template já força `LANG`/`LC_ALL=C.UTF-8`.
- **Feedback:** saída legível, com resumo final do que foi criado/alterado.

---

## 6. Fora de escopo (por ora)

- Conteúdo de produção (Dockerfile/compose de produção na raiz do projeto gerado).
- Instalação automática de plugins fora do container (o menu apenas grava os comandos em
  `postCreate.sh`; a instalação de fato roda dentro do devcontainer, na próxima criação).
- Publicação/hospedagem dos scripts em uma URL estável própria (hoje o `README.md` aponta para o
  `raw.githubusercontent.com` do branch `main`).
- Skills reais em `.claude/skills/` (só o ponto de extensão existe).

---

## 7. Roadmap / evolução

- Popular `.claude/skills/` com skills reutilizáveis de fato.
- Ampliar o catálogo de `scripts/plugins.sh` (hoje: agent-browser, Context7, context-mode).
- Testar o bootstrap em Windows real (a validação atual usou PowerShell 7 em Linux); confirmar
  comportamento de permissões de execução do `postCreate.sh` quando o bind mount vem do Windows.
- Considerar publicar um release/tag estável para `install.sh`/`install.ps1` apontarem, em vez de
  sempre baixar do `main`.

---

## 8. Critérios de aceite

Após rodar o bootstrap em um diretório vazio, o resultado deve satisfazer (checklist validado
manualmente em bash e PowerShell 7 durante a construção deste kit):

- [x] Existe um projeto novo com um `.git` **próprio** (via `git init`), sem o `.git` do template.
- [x] `.devcontainer/devcontainer.json` tem `name` e `description` com os valores informados, e
      continua sendo JSON válido.
- [x] `.env` foi gerado a partir do `.env.example` com `CONTAINER_NAME`/`DOCKER_IMAGE_NAME`
      derivados (slugificados) do nome do devcontainer, e `DOCKER_IMAGE_TAG` reiniciado em `0.1`.
- [x] `PRD.md` e `install.*` **não** estão presentes no projeto gerado; `.claude/PRD.md`
      (esqueleto) permanece.
- [x] Os agentes genéricos e demais arquivos do kit (devcontainer, scripts, settings, skills)
      permanecem.
- [x] O usuário pôde escolher, opcionalmente, quais plugins instalar (default: nenhum); a escolha
      é gravada no bloco marcado de `postCreate.sh`.
- [x] O fluxo funciona tanto no `install.sh` (Linux/macOS) quanto no `install.ps1` (Windows/
      PowerShell), com o mesmo resultado observável.
- [x] Rodar em diretório não vazio sem `--force`/`-Yes` aborta com mensagem clara (exit ≠ 0) nos
      dois scripts, inclusive sem terminal interativo disponível.
