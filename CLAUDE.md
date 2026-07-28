# CLAUDE.md

Orientações para o Claude Code trabalhar neste repositório.

> **Fonte de verdade do produto:** [`.claude/PRD.md`](.claude/PRD.md) (o quê e por quê).
> Este arquivo descreve **como** trabalhar aqui. Em caso de conflito entre este documento e o
> PRD, o PRD vence — e o conflito deve ser corrigido, não contornado.
>
> `CLAUDE.md` é artefato **só do template** (`[t]`): os instaladores o excluem do projeto gerado.

---

## 1. O que é este repositório

`devc-debian-claude` é um **template (esqueleto) de projeto**, não uma aplicação. Ele entrega um
Devcontainer Debian com Claude Code, ferramentas de desenvolvimento e um catálogo de skills/plugins,
mais um **instalador de um comando** que materializa um projeto novo a partir dele.

Não há código de aplicação, não há build, não há suíte de testes automatizados
(testes dos instaladores estão explicitamente fora de escopo — PRD §9).
O "produto" são: os scripts de bootstrap, a imagem de desenvolvimento e a configuração do devcontainer.

**Idioma:** todo conteúdo do repositório (comentários, mensagens de script, documentação) é em
**português**. Mantenha assim.

---

## 2. Invariante central — paridade de caminho

`PROJECT_FOLDER` (em `.devcontainer/.env`) **=** `workspaceFolder` (em `.devcontainer/devcontainer.json`)
**=** caminho absoluto da pasta do projeto no host.

Essa é a restrição estrutural do produto (PRD §1, RF3): garante que o Claude Code enxergue o mesmo
caminho absoluto no host e dentro do container, preservando configuração, memória e sessões.
Se os dois divergirem, **a instalação é inválida**. Nunca "simplifique" para `/workspace` ou
`/workspaces/${localWorkspaceFolderBasename}`.

O instalador coleta **um** caminho (padrão: a pasta de instalação; ou `--project-folder` /
`INSTALL_PROJECT_FOLDER`) e o grava nos dois arquivos de uma vez — nunca em só um. Caminho
relativo é rejeitado.

Neste repositório-template o valor atual é `/code/pessoal/devc-debian-claude`, em ambos os arquivos.

---

## 3. Mapa dos arquivos

Marcação do PRD §8: `[i]` = copiado para o projeto gerado; `[t]` = só existe no template;
`[g]` = gerado, não versionado.

| Caminho | | Papel |
|---|---|---|
| `.devcontainer/Dockerfile` | `[i]` | Imagem `debian:bookworm-slim` + Node LTS/npm, `uv`, Bun, `git`, `gh`, `sudo`, zip/unzip/xz, Chrome, `ccusage`, `claude-usage`; usuário `app` (UID/GID 1000) |
| `.devcontainer/docker-compose.yml` | `[i]` | Serviço `app`; bind `..:${PROJECT_FOLDER}:cached`; `user: ${HOST_UID:-1000}:${HOST_GID:-1000}` |
| `.devcontainer/devcontainer.json` | `[i]` | Feature `claude-code`, bind de `~/.claude`, `CLAUDE_CONFIG_DIR`, locale, override do `credential.helper` |
| `.devcontainer/postCreate.sh` | `[i]` | Recria `~/.git-credentials` e `GH_TOKEN` a partir do `.env` da raiz |
| `.devcontainer/devcontainer-lock.json` | `[i]` | Versão travada da feature `claude-code` |
| `.devcontainer/.env.example` → `.env` | `[i]`/`[g]` | `DOCKER_IMAGE_NAME`, `DOCKER_IMAGE_TAG`, `CONTAINER_NAME`, `PROJECT_FOLDER` |
| `scripts/install.sh` / `install.ps1` | `[i]` | Bootstrap Linux/macOS e Windows |
| `scripts/install-skill.sh` | `[i]` | Catálogo de skills (`npx skills add ...`) — catálogo, não executável de uma vez |
| `scripts/plugins.sh` | `[i]` | Catálogo de plugins/MCPs sob demanda |
| `scripts/clean.sh` | `[i]` | Remove container e volumes deste devcontainer |
| `prompts/` | `[i]` | `1-create-prd.md`, `2-create-claude.md`, `3-create-agents.md`, `4-create-readme.md` — prompts numerados na ordem de uso |
| `skills-lock.json` | `[i]` | Lock (origem/caminho/hash) das skills instaladas |
| `.claude/settings.json` | `[i]` | Hooks (bell em `Stop` e `Notification`) |
| `.claude/agents/` | `[i]` | Subagentes; hoje só `sdd-reviewer.md` |
| `README.md` | `[t]` | Documentação pública do template; não vai para o projeto gerado |
| `.claude/PRD.md` | `[t]` | Este PRD; no projeto gerado vira um **esqueleto novo** escrito pelo instalador |
| `.claude/settings.local.json` | `[g]` | `skillOverrides` — skills desativadas neste projeto |
| `.claude/skills/` | `[t]` | Symlinks versionados para `../../.agents/skills/*`; descartados na instalação (senão ficariam quebrados) |
| `.agents/skills/` | `[t]` | Skills materializadas; **não** vai para o projeto gerado |
| `.env.example` → `.env` | `[i]`/`[g]` | `GIT_USERNAME`, `GIT_EMAIL`, `GIT_NAME`, `GIT_TOKKEN` (grafia com dois K é a real) |

**Lista fechada do RF6** — o projeto gerado recebe **apenas**: `.claude/` (exceto `settings.local.json`,
`PRD.md` e os symlinks de `skills/`), `.devcontainer/`, `prompts/`, `scripts/`, `.env.example`,
`.gitignore`, `skills-lock.json` — mais o `.claude/PRD.md` esqueleto. Nada além disso. Ao mexer nos
instaladores, verifique essa lista: ela é implementada como cópia item a item (nunca "copia tudo e
apaga depois") e é validada por inteiro antes de a primeira cópia acontecer.

---

## 4. Comandos

Não há `make`, `npm test` ou pipeline. O que se roda aqui:

```bash
bash scripts/install.sh --help          # bootstrap; ver flags
bash scripts/clean.sh                   # remove container/volumes (preserva o volume "vscode")
bash scripts/clean.sh -y                # sem confirmação
bash .devcontainer/postCreate.sh        # idempotente; roda sozinho no create do container
```

`scripts/install-skill.sh` e `scripts/plugins.sh` são **catálogos para copiar-e-colar linha a linha**,
não scripts a executar inteiros — instalar tudo polui o container (PRD §2, RF10).

Validação manual do ambiente (critérios de aceite do PRD §10):

```bash
whoami            # app
locale            # C.UTF-8
for c in node npm uv bun git gh sudo ccusage claude-usage; do command -v $c; done
```

---

## 5. Convenções ao editar

**Instaladores (`install.sh` / `install.ps1`)** — os dois são a mesma especificação em dois idiomas:
**toda mudança em um exige a mudança equivalente no outro**. Ambos devem: abortar em pasta não vazia
sem `--yes`/`-Yes`, funcionar sem TTY, clonar com `--depth 1`, apagar o `.git` do template,
respeitar a lista fechada do RF6, gravar `PROJECT_FOLDER`/`workspaceFolder` com o `pwd` da instalação,
derivar `DOCKER_IMAGE_NAME`/`CONTAINER_NAME` do nome do projeto normalizado, gerar o `.claude/PRD.md`
esqueleto e rodar `git init` (+ commit, salvo `--no-commit`).

Normalização do nome (RF2): espaços → `-`, tudo minúsculo (a `slugify` também remove acentos e
outros caracteres inválidos em nome de container). `Meu Projeto Novo` → `meu-projeto-novo`, usado
também como nome do container. **Não existe pergunta, flag nem variável para o nome do container** —
não reintroduza `--container`/`INSTALL_CONTAINER`.

Reescrita do `devcontainer.json`: é feita **linha a linha**, substituindo tudo que vier depois de
`"name":`, `"description":` e `"workspaceFolder":`, sem casar o valor antigo. O arquivo é **JSONC** —
não passe por `ConvertFrom-Json`/`jq`, que apagam os comentários. Os valores entram pelo ambiente
(`ENVIRON` no awk), nunca por `awk -v`, que reprocessaria os escapes.

**Dockerfile** — enxuto: `--no-install-recommends` e `rm -rf /var/lib/apt/lists/*` em cada camada.
Cuidado com **`USER` e `$HOME` durante o build**: o que grava em `~` (Bun, `uv tool install`) precisa
rodar **depois do `USER app`**, senão vai para `/root/...` e fica fora do PATH; e o `ENV PATH` precisa
vir **antes** dessas instalações, senão elas avisam que o diretório não está no PATH. Instalação
global via npm (`ccusage`) fica antes do `USER app`. `arch=amd64` é fixo (Chrome e `gh`);
multiarquitetura está fora de escopo.

**`devcontainer.json`** — o bloco `GIT_CONFIG_*` com `VALUE_0` **vazio** é intencional:
`credential.helper` é cumulativo, e o valor vazio zera a lista injetada pela extensão Dev Containers
antes de definir `store`. Junto com `dev.containers.copyGitConfig: false`, é o que faz `git push`
funcionar no container. Não "limpe" isso. O arquivo usa comentários (JSONC) — preserve-os.

**Segredos** — `.env` e `.devcontainer/.env` são ignorados pelo git; arquivos com token vão com
`chmod 600`. Nunca versione valores reais nem os imprima em log. O instalador **não** preenche o
`.env` da raiz (é preenchimento manual do usuário — PRD §11).

**`postCreate.sh`** — precisa ser idempotente: rodar duas vezes não pode duplicar linha no `~/.bashrc`
(hoje via `grep -qF`), e `.env` ausente/incompleto deve pular o passo com mensagem e **sair com sucesso**.
A raiz do projeto é resolvida pelo caminho do próprio script, nunca pelo nome da pasta.

**Skills** — versionadas em `.agents/skills/` + `skills-lock.json`; desativação por projeto em
`.claude/settings.local.json` (`skillOverrides: {"<skill>": "off"}`). Skill desativada **continua
versionada**, só não é ativada. Plugins/MCPs **nunca** são instalados automaticamente.

---

## 6. Estado da conformidade com o PRD

Verificado em 2026-07-28.

**Corrigido e testado** (`install.sh` executado ponta a ponta contra uma cópia local do template):

* **RF2** — a pergunta/flag do nome do container foi removida dos dois instaladores; o slug vem do
  nome do projeto.
* **RF3** — os instaladores coletam o caminho do projeto (padrão: pasta de instalação) e gravam
  `PROJECT_FOLDER` **e** `workspaceFolder` com ele; caminho relativo aborta.
* **RF5** — reescrita linha a linha de `name`/`description`/`workspaceFolder`, com `description`
  inserida quando ausente, comentários JSONC preservados e erro se `name` ou `workspaceFolder`
  não existirem.
* **RF6** — cópia da lista fechada item a item, validada antes de começar; symlinks de
  `.claude/skills/` descartados para não gerar links quebrados. O `rm -f install.sh install.ps1`
  (no-op) foi removido.
* **RF7** — Dockerfile reordenado: `ENV PATH` antes do `USER app`, e Bun + `uv tool install`
  depois dele, para que os binários caiam em `/home/app/...`.

**Pendências conhecidas** — defeitos abertos; ao tocar nesses pontos, corrija na direção do PRD:

1. **`install.ps1` não foi executado**: não há PowerShell neste container. As mudanças espelham o
   `install.sh` linha a linha, mas o caminho Windows segue sem verificação.
2. **Dockerfile não foi reconstruído**: não há Docker disponível aqui. A correção do RF7 é uma
   mudança de ordem `USER`/`ENV`, ainda não validada por build. O container em execução ainda é o
   antigo, onde `bun` e `claude-usage` **não** respondem no PATH — vale um rebuild para confirmar.
3. **Esqueleto de `.claude/PRD.md`** (gerado pelos instaladores) ainda menciona subagentes
   `plan-dev`, `run-dev`, `test-ops`, `plan-ops` e `run-ops`, que não existem. Hoje
   `.claude/agents/` contém apenas `sdd-reviewer.md` (veio com a skill `sdd-review`), e
   `prompts/3-create-agents.md` prevê um terceiro conjunto (`review-*`) — PRD §11.
4. **URLs de download desalinhadas**: os cabeçalhos de `install.sh`/`install.ps1` ainda citam
   `.../main/install.sh` na raiz, enquanto os arquivos vivem em `scripts/`. O `README.md` já usa
   o caminho correto (`.../main/scripts/install.sh`).

---

## 7. Limites de escopo

Fora da primeira versão (PRD §9): Dockerfile/compose de produção na raiz, instalação automática de
plugins/MCPs, suporte a `arm64`, testes automatizados dos instaladores. Não introduza esses itens
sem que o PRD mude antes.
