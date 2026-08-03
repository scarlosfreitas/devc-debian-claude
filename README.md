# devcontainer-ia-cli

![Debian](https://img.shields.io/badge/base-debian%20bookworm--slim-A81D33?logo=debian&logoColor=white)
![Dev Containers](https://img.shields.io/badge/Dev%20Containers-VS%20Code-007ACC?logo=visualstudiocode&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-D97757)
![Codex CLI](https://img.shields.io/badge/Codex%20CLI-412991)
![Gemini CLI](https://img.shields.io/badge/Gemini%20CLI-4285F4)

Imagem Docker + estrutura de projeto para desenvolvimento com **CLIs de IA em linha de comando**,
rodando lado a lado em um único Devcontainer Debian: **Claude Code**, **Codex CLI**, **Gemini CLI**
e **Antigravity CLI**. Instale com um comando e comece a codar com o assistente de sua escolha.

> A fonte de verdade do produto é o [`.claude/PRD.md`](.claude/PRD.md) (o quê e por quê).
> As convenções de trabalho no repositório estão no [`CLAUDE.md`](CLAUDE.md) (como).

---

## Ferramentas integradas

| Categoria | Ferramentas |
|---|---|
| **CLIs de IA** | Claude Code (`claude`), Codex CLI (`codex`), Gemini CLI (`gemini`), Antigravity CLI (`agy`) |
| **Gerenciadores de pacote** | `uv`/`uvx` (Python), Node.js 24 + `npm` (JavaScript), Bun |
| **Consumo de tokens** | `ccusage` (Claude Code), `claude-usage` (painel agregado) |
| **Spec-driven development** | OpenSpec (`/opsx:*`) |
| **Versionamento** | `git`, GitHub CLI (`gh`) |
| **Docker-out-of-Docker** | `docker`, `docker compose` (cliente; fala com o daemon do host) |
| **Apoio** | `nano` (editor), `ping`/`iproute2` (rede), Google Chrome (automação de navegador) |

Cada CLI de IA tem seu diretório de configuração (`~/.claude`, `~/.gemini`, `~/.codex`) montado do
host para o container por bind mount, então login e credenciais sobrevivem a rebuilds.

O template ainda traz um **catálogo de skills e plugins** para Claude Code (Docker, Postgres,
Kafka, Dagster, Proxmox, Azure, MCP, entre outros), instalados sob demanda — nunca todos de uma vez.

## Como usar

### 1. Criar um projeto novo a partir do template

```bash
curl -fsSL https://raw.githubusercontent.com/scarlosfreitas/devcontainer-ia-cli/main/scripts/install.sh | bash
```

O instalador pergunta **nome** e **descrição** do projeto, baixa a estrutura de devcontainer,
scripts e prompts, e inicializa um repositório git novo. O nome do container é derivado do nome do
projeto — não é perguntado separadamente. Ver todas as opções (modo não-interativo, caminho
customizado etc.) com:

```bash
bash scripts/install.sh --help
```

### 2. Construir (ou publicar) a imagem

O `docker-compose.yml` referencia a imagem por nome:tag em vez de buildar automaticamente. Antes do
primeiro "Reopen in Container", gere a imagem a partir do projeto que você acabou de criar (ver
`--local` em "Comandos úteis"), ou aponte `.devcontainer/.env` para uma imagem já publicada.

### 3. Preencher as credenciais git

```bash
cp .env.example .env            # GIT_USERNAME, GIT_EMAIL, GIT_NAME
cp .secrets.example .secrets    # GIT_TOKKEN (fica separado por ser segredo)
```

### 4. Abrir no devcontainer

No VS Code: `Ctrl+Shift+P` → **Dev Containers: Reopen in Container**. O `postCreate.sh` configura
git/`gh` automaticamente a partir de `.env`/`.secrets`.

### 5. Autenticar e trabalhar

Faça login em cada CLI de IA que for usar (`claude`, `codex`, `gemini` ou `agy`) e comece a
trabalhar — o caminho do projeto é idêntico no host e no container (`PROJECT_FOLDER` =
`workspaceFolder`), preservando sessões e memória.

## Comandos úteis

```bash
bash scripts/build-image-devcontainer.sh          # builda a imagem baixando do GitHub (padrão)
bash scripts/build-image-devcontainer.sh --local  # builda a partir dos arquivos locais
bash scripts/clean.sh -y       # remove container/volumes deste projeto (preserva o volume "vscode")
bash scripts/install-skill.sh  # catálogo de skills (copiar-e-colar linha a linha)
bash scripts/plugins.sh        # catálogo de plugins/MCPs sob demanda
```

## Estrutura

```text
.devcontainer/   Dockerfile-devcontainer, docker-compose.yml, devcontainer.json, postCreate.sh
scripts/         install.sh / install.ps1, build-image-devcontainer.sh, clean.sh, catálogos de skills/plugins
prompts/         roteiro numerado: PRD, CLAUDE.md, subagentes de revisão e README do projeto
.claude/         skill + subagente de revisão SDD (proposal → apply), sem escrever arquivo algum
```
