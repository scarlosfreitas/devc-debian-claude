# CLAUDE.md

Orientações para o Claude Code trabalhar neste repositório.

> **Fonte de verdade do produto:** [`.claude/PRD.md`](.claude/PRD.md) (o quê e por quê).
> Este arquivo descreve **como** trabalhar aqui. Em caso de conflito entre este documento e o
> PRD, o PRD vence — e o conflito deve ser corrigido, não contornado.
>
> `CLAUDE.md` é artefato **só do template** (`[t]`): os instaladores o excluem do projeto gerado.

---

## 1. O que é este repositório

`devcontainer-ai-cli` (antigo `devc-debian-claude`) é um **template (esqueleto) de projeto**, não
uma aplicação. Ele entrega uma **imagem Docker e uma estrutura de projeto** para desenvolvimento
com **CLIs de IA** — Claude Code (Anthropic), Codex CLI (OpenAI), Gemini CLI e Antigravity CLI/`agy`
(Google) —, seus gerenciadores de pacote (`uv`, `npm`/Node.js, Bun) e ferramentas de apoio
(edição de texto, rede, Docker-out-of-Docker, `gh`, OpenSpec, monitoramento de tokens), mais um
**instalador de um comando** que materializa um projeto novo a partir dele — e a **trilha de
revisão SDD** (§5.1) que se usa dentro do projeto gerado.

Não há código de aplicação, não há build de software, não há suíte de testes automatizados
(testes dos instaladores estão explicitamente fora de escopo — PRD §9).
O "produto" são: a imagem de desenvolvimento (`.devcontainer/Dockerfile-devcontainer`), os scripts de bootstrap
e build, a configuração do devcontainer e os prompts/subagentes de revisão.

**Idioma:** todo conteúdo do repositório (comentários, mensagens de script, documentação) é em
**português**. Mantenha assim.

---

## 2. Invariante central — paridade de caminho

`PROJECT_FOLDER` (em `.devcontainer/.env`) **=** `workspaceFolder` (em `.devcontainer/devcontainer.json`)
**=** caminho absoluto da pasta do projeto no host.

Essa é a restrição estrutural do produto (PRD §1, RF3): garante que os CLIs de IA enxerguem o mesmo
caminho absoluto no host e dentro do container, preservando configuração, memória e sessões.
Se os dois divergirem, **a instalação é inválida**. Nunca "simplifique" para `/workspace` ou
`/workspaces/${localWorkspaceFolderBasename}`.

O instalador coleta **um** caminho (padrão: a pasta de instalação; ou `--project-folder` /
`INSTALL_PROJECT_FOLDER`) e o grava nos dois arquivos de uma vez — nunca em só um. Caminho
relativo é rejeitado.

Neste repositório-template o valor atual é `/code/pessoal/devcontainer-ai-cli`, em ambos os
arquivos.

---

## 3. Mapa dos arquivos

Marcação do PRD §8: `[i]` = copiado para o projeto gerado; `[t]` = só existe no template;
`[g]` = gerado, não versionado.

| Caminho | | Papel |
|---|---|---|
| `.devcontainer/Dockerfile-devcontainer` | `[i]` | Imagem `debian:bookworm-slim` + CLIs de IA (Claude Code, Codex CLI, Gemini CLI, Antigravity CLI), gerenciadores de pacote (`uv`, Node 24/npm, Bun), `git`/`gh`, cliente Docker (DooD), `ccusage`/`claude-usage`, OpenSpec, Chrome, `nano`, rede (`ping`/`iproute2`), `sudo`; usuário `app` (UID/GID 1000) — lista completa no PRD RF7 |
| `.devcontainer/docker-compose.yml` | `[i]` | Serviço `app`; referencia a imagem por `${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}` (o `build:` fica comentado, RF13); bind `..:${PROJECT_FOLDER}:cached`; `user: ${HOST_UID:-1000}:${HOST_GID:-1000}` |
| `.devcontainer/devcontainer.json` | `[i]` | Bind de `~/.claude`, `~/.gemini`, `~/.codex`; `CLAUDE_CONFIG_DIR`, locale, override do `credential.helper` |
| `.devcontainer/postCreate.sh` | `[i]` | Recria `~/.git-credentials` e `GH_TOKEN` a partir de `.env`/`.secrets` da raiz |
| `.devcontainer/devcontainer-lock.json` | `[i]` | **Órfão** — travava a feature `claude-code`, não mais referenciada em `devcontainer.json` (ver §6) |
| `.devcontainer/.env.example` → `.env` | `[i]`/`[g]` | `DOCKER_IMAGE_NAME`, `DOCKER_IMAGE_TAG`, `CONTAINER_NAME`, `PROJECT_FOLDER` |
| `scripts/install.sh` / `install.ps1` | `[i]` | Bootstrap Linux/macOS e Windows |
| `scripts/install-skill.sh` | `[i]` | Catálogo de skills (`npx skills add ...`) — catálogo, não executável de uma vez |
| `scripts/plugins.sh` | `[i]` | Catálogo de plugins/MCPs sob demanda |
| `scripts/clean.sh` | `[i]` | Remove container e volumes deste devcontainer |
| `scripts/build-image-devcontainer.sh` | `[i]` | Builda `Dockerfile-devcontainer` fora do compose (RF13); padrão baixa `.env.example`/`Dockerfile-devcontainer` do GitHub, `--local` usa `.devcontainer/.env`/`Dockerfile-devcontainer` locais — mecanismo primário de build, já que o compose não builda mais sozinho |
| `prompts/` | `[i]` | `1-create-prd.md`, `2-create-claude.md`, `3-create-agents.md`, `4-create-readme.md`, `5-new-feature-script.md` (vazio), `6-final-review.md` — numerados na ordem de uso |
| `skills-lock.json` | `[i]` | Lock (origem/caminho/hash) das skills instaladas |
| `.claude/agents/` | `[i]` | Subagentes; hoje só `sdd-reviewer.md` (camada 1 do RF12) |
| `.claude/skills/sdd-review/` | `[t]` | Pasta real (não symlink): processo de revisão de change OpenSpec |
| `README.md` | `[t]` | Documentação pública do template; não vai para o projeto gerado |
| `.claude/PRD.md` | `[t]` | Este PRD; **não** vai para o projeto gerado, nem como esqueleto — o usuário escreve o seu (`prompts/1-create-prd.md`) |
| `.claude/settings.local.json` | `[g]` | `skillOverrides` — skills desativadas neste projeto |
| `.claude/skills/` | `[t]` | Symlinks versionados para `../../.agents/skills/*`; descartados na instalação (senão ficariam quebrados) |
| `.agents/skills/` | `[t]` | Skills materializadas; **não** vai para o projeto gerado |
| `.env.example` → `.env` | `[i]`/`[g]` | `GIT_USERNAME`, `GIT_EMAIL`, `GIT_NAME` — configuração git não-sensível |
| `.secrets.example` → `.secrets` | `[i]`/`[g]` | `GIT_TOKKEN` — separado de `.env` por ser segredo (grafia com dois K é a real) |
| `.vscode/settings.json` | `[t]` | Oculta `.worktrees/` da árvore/busca do editor |
| `.worktrees/` | `[t]` | Destino de `git worktree add` para checkouts paralelos de branch; ignorado pelo git |

**Lista fechada do RF6** — o projeto gerado recebe **apenas**: `.claude/` (exceto `settings.local.json`,
`PRD.md` e os symlinks de `skills/`), `.devcontainer/`, `prompts/`, `scripts/`, `.env.example`,
`.secrets.example`, `.gitignore`, `skills-lock.json`. Nada além disso — em especial, `.claude/PRD.md`
**não** é regerado como esqueleto; o projeto nasce sem PRD. Ao mexer nos instaladores, verifique essa
lista: ela é implementada como cópia item a item (nunca "copia tudo e apaga depois") e é validada por
inteiro antes de a primeira cópia acontecer.

---

## 4. Comandos

Não há `make`, `npm test` ou pipeline. O que se roda aqui:

```bash
bash scripts/install.sh --help          # bootstrap; ver flags
bash scripts/clean.sh                   # remove container/volumes (preserva o volume "vscode")
bash scripts/clean.sh -y                # sem confirmação
bash .devcontainer/postCreate.sh        # idempotente; roda sozinho no create do container
bash scripts/build-image-devcontainer.sh          # builda a imagem baixando do GitHub (padrão); necessário antes do 1º "Reopen in Container"
bash scripts/build-image-devcontainer.sh --local  # builda a partir do .devcontainer/.env e Dockerfile-devcontainer locais
```

`scripts/install-skill.sh` e `scripts/plugins.sh` são **catálogos para copiar-e-colar linha a linha**,
não scripts a executar inteiros — instalar tudo polui o container (PRD §2, RF10).

Validação manual do ambiente (critérios de aceite do PRD §10):

```bash
whoami            # app
locale            # C.UTF-8
for c in node npm uv bun git gh sudo docker nano ping ccusage claude-usage openspec claude codex gemini agy; do command -v $c; done
```

---

## 5. Convenções ao editar

**Instaladores (`install.sh` / `install.ps1`)** — os dois são a mesma especificação em dois idiomas:
**toda mudança em um exige a mudança equivalente no outro**. Ambos devem: abortar em pasta não vazia
sem `--yes`/`-Yes`, funcionar sem TTY, clonar com `--depth 1`, apagar o `.git` do template,
respeitar a lista fechada do RF6, gravar `PROJECT_FOLDER`/`workspaceFolder` com o `pwd` da instalação,
derivar `DOCKER_IMAGE_NAME`/`CONTAINER_NAME` do nome do projeto normalizado e rodar `git init` (+
commit, salvo `--no-commit`). Nenhum dos dois gera `.claude/PRD.md`: o `.claude/PRD.md` do template
é removido junto com `settings.local.json`, e não é substituído por nada.

Normalização do nome (RF2): espaços → `-`, tudo minúsculo (a `slugify` também remove acentos e
outros caracteres inválidos em nome de container). `Meu Projeto Novo` → `meu-projeto-novo`, usado
também como nome do container. **Não existe pergunta, flag nem variável para o nome do container** —
não reintroduza `--container`/`INSTALL_CONTAINER`.

Reescrita do `devcontainer.json`: é feita **linha a linha**, substituindo tudo que vier depois de
`"name":`, `"description":` e `"workspaceFolder":`, sem casar o valor antigo. O arquivo é **JSONC** —
não passe por `ConvertFrom-Json`/`jq`, que apagam os comentários. Os valores entram pelo ambiente
(`ENVIRON` no awk), nunca por `awk -v`, que reprocessaria os escapes.

**`Dockerfile-devcontainer`** — enxuto: `--no-install-recommends` e `rm -rf /var/lib/apt/lists/*` em cada camada.
Os quatro CLIs de IA (Claude Code, Codex CLI, Gemini CLI via `npm install -g`; Antigravity CLI via
instalador oficial) e o ferramental de apoio (Bun, `claude-usage`, OpenSpec) são instalados
globalmente ainda como root, **antes** do `USER app` — cada instalador que por padrão gravaria em
`$HOME` é redirecionado para um diretório global via env var/flag (`BUN_INSTALL=/usr/local` no Bun;
`UV_TOOL_DIR`/`UV_TOOL_BIN_DIR` apontando para `/usr/local/...` no `uv tool install` do
`claude-usage`; `--dir /usr/local/bin` no instalador do Antigravity), em vez de rodar como usuário
`app` depois de `USER app`. Os diretórios `/home/app/.claude`, `/home/app/.gemini` e
`/home/app/.codex` são pré-criados com dono `app:app` **antes** do `USER app`, para que os bind
mounts do `devcontainer.json` (RF8) herdem a permissão certa na primeira subida. Não há mais
nenhum `RUN` depois do `USER app` hoje — só `WORKDIR`. **Cuidado com `USER` e `$HOME` durante o
build** continua valendo como princípio geral para ferramentas *futuras*: se um instalador novo não
suportar redirecionar seu diretório de destino, ele volta a precisar do padrão antigo (rodar como
usuário `app`, com `ENV PATH` declarado antes). `arch=amd64` é fixo (Chrome e `gh`); multiarquitetura
está fora de escopo. O cliente Docker (`docker-ce-cli`/`docker-compose-plugin`) é só o cliente —
o comentário do `Dockerfile-devcontainer` assume um mount de `/var/run/docker.sock` que **não existe** hoje em
`devcontainer.json` (pendência, §6); não assuma DooD funcional sem checar isso primeiro.

**`devcontainer.json`** — o bloco `GIT_CONFIG_*` com `VALUE_0` **vazio** é intencional:
`credential.helper` é cumulativo, e o valor vazio zera a lista injetada pela extensão Dev Containers
antes de definir `store`. Junto com `dev.containers.copyGitConfig: false`, é o que faz `git push`
funcionar no container. Não "limpe" isso. O arquivo usa comentários (JSONC) — preserve-os. Os três
mounts (`~/.claude`, `~/.gemini`, `~/.codex`) seguem o mesmo padrão: qualquer CLI de IA novo que
entrar na imagem (RF7) precisa do mount equivalente aqui, senão perde config/credenciais a cada
rebuild (RF8).

**`scripts/build-image-devcontainer.sh` (RF13)** — builda `.devcontainer/Dockerfile-devcontainer`
fora do `docker-compose`, em dois modos:

* **Padrão (remoto)** — clona `REPO_URL`/`BRANCH` (default: `devcontainer-ai-cli`/`main`) num
  diretório temporário e lê `DOCKER_IMAGE_NAME`/`DOCKER_IMAGE_TAG` de `.devcontainer/.env.example`
  ali dentro. Existe para funcionar como downloader avulso (`curl | bash`, igual ao `install.sh`),
  sem exigir um clone local do projeto.
* **`--local`** — usa `.devcontainer/.env` e `.devcontainer/Dockerfile-devcontainer` do próprio
  projeto onde o script está (resolvido pelo caminho do script, mesmo padrão de `clean.sh`), para
  testar mudanças no Dockerfile antes de publicá-las.

Em ambos os modos, o valor lido é `DOCKER_IMAGE_NAME`/`DOCKER_IMAGE_TAG` — as **mesmas** variáveis
que o `docker-compose.yml` já usa para `image:`, não campos novos. Qualquer opção não reconhecida
(`--local`, `--repo-url`, `--branch`, `-h`) é repassada ao `docker build` (ex.: `--no-cache`).
Existe para permitir gerar/publicar essa imagem e reutilizá-la como base em projetos futuros
(`FROM`) sem duplicar o Dockerfile. Não há um segundo Dockerfile na raiz: já se cogitou isso (imagem
multiestágio separada) e foi descartado, porque quase tudo instalado no `Dockerfile-devcontainer` é
pacote `apt`/`npm` — não há alvo de build pesado para "copiar só os binários", e replicar o
ferramental num segundo arquivo só criaria dessincronia para manter. Como `scripts/` é copiado por
inteiro (RF6) e `.devcontainer/` também, este script funciona normalmente em projetos gerados a
partir do template (no modo `--local`).

**Segredos** — `GIT_TOKKEN` mora em `.secrets` (não em `.env`): a separação existe para isolar o
único valor realmente sensível do resto da configuração git (`GIT_USERNAME`/`GIT_EMAIL`/`GIT_NAME`,
em `.env`). `.env`, `.secrets` e `.devcontainer/.env` são ignorados pelo git; arquivos com token vão
com `chmod 600`. Nunca versione valores reais nem os imprima em log. O instalador **não** preenche
`.env`/`.secrets` da raiz (é preenchimento manual do usuário — PRD §11). Ao editar `postCreate.sh`,
lembre que `GIT_USERNAME` vem de `.env` e `GIT_TOKKEN` vem de `.secrets` — não junte os dois de
volta num arquivo só.

**`postCreate.sh`** — precisa ser idempotente: rodar duas vezes não pode duplicar linha no `~/.bashrc`
(hoje via `grep -qF`), e `.env` ausente/incompleto deve pular o passo com mensagem e **sair com sucesso**.
A raiz do projeto é resolvida pelo caminho do próprio script, nunca pelo nome da pasta.

**Skills** — versionadas em `.agents/skills/` + `skills-lock.json`; desativação por projeto em
`.claude/settings.local.json` (`skillOverrides: {"<skill>": "off"}`). Skill desativada **continua
versionada**, só não é ativada. Plugins/MCPs **nunca** são instalados automaticamente.

---

## 5.1 Trilha de revisão SDD (PRD RF12)

Duas camadas independentes, em momentos diferentes do ciclo. **Nenhuma das duas escreve arquivos** —
o produto de ambas é um relatório. Ao editar qualquer peça, preserve essa propriedade.

**Camada 1 — antes do Apply.** Skill `sdd-review` (o processo, em `.claude/skills/sdd-review/`) +
subagente `sdd-reviewer` (o executor, em `.claude/agents/`). Posição obrigatória no ciclo:
**depois do `/opsx:propose`, antes do `/opsx:apply`**. Revisa os artefatos da change
(`proposal.md`, `design.md`, `tasks.md`, `specs/`) mais o `CLAUDE.md` do projeto, em seis etapas —
Consistência, Escopo, Arquitetura, Implementação, Banco de Dados, Riscos — e conclui com um veredito
binário: *Pronto para Apply* ou *Requer ajustes antes do Apply*.

O `sdd-reviewer` declara `tools: Read, Grep, Glob` e `disallowed-tools: Write, Edit, NotebookEdit,
Bash`. Isso **não é preferência de estilo**: um revisor que corrige deixa de ser controle
independente. Não adicione ferramenta de escrita a esse agente, nem afrouxe a instrução de que
mesmo erros triviais são apenas reportados, com localização exata.

Mexeu na skill? Confira se o `sdd-reviewer.md` continua coerente — ele referencia as seis etapas por
nome e o formato de saída em quatro seções.

**Camada 2 — entre ciclos.** Subagentes `review-architect`, `review-performance`, `review-blazor`,
`review-ui` e `review-manager`, **gerados no projeto destino** por `prompts/3-create-agents.md` e
acionados por `prompts/6-final-review.md`; não são versionados aqui. Revisam o projeto implementado
muito além do código (arquitetura, desempenho, ciclo de vida do framework, UX, acessibilidade). O
`review-manager` só consolida — não analisa código e **não reinterpreta** as conclusões dos
especialistas — e grava `docs/reviews/review-AAAA-MM-DD.md`, cuja seção *Próximos Passos* alimenta
o `/opsx:propose` seguinte.

Ao editar `3-create-agents.md`, respeite o que o próprio prompt exige: estrutura fixa
(`name`/`description` + Objetivo, Responsabilidades, Critérios de análise, Formato da resposta),
sem simplificar instrução, sem eliminar informação e sem reorganizar. Os dois prompts se espelham na
lista de especialistas e nas premissas de stack — **mudança em um exige a mudança equivalente no
outro**, como acontece com os instaladores.

---

## 6. Estado da conformidade com o PRD

Verificado em 2026-08-03, após a mudança de escopo para "imagem + estrutura de projeto para CLIs
de IA" (repositório e projeto renomeados de `devc-debian-claude` para `devcontainer-ai-cli`).

**Corrigido e testado** (`install.sh` executado ponta a ponta contra uma cópia local do template,
em uma versão anterior do escopo):

* **RF2** — a pergunta/flag do nome do container foi removida dos dois instaladores; o slug vem do
  nome do projeto.
* **RF3** — os instaladores coletam o caminho do projeto (padrão: pasta de instalação) e gravam
  `PROJECT_FOLDER` **e** `workspaceFolder` com ele; caminho relativo aborta.
* **RF5** — reescrita linha a linha de `name`/`description`/`workspaceFolder`, com `description`
  inserida quando ausente, comentários JSONC preservados e erro se `name` ou `workspaceFolder`
  não existirem.
* **RF6** — cópia da lista fechada item a item, validada antes de começar; symlinks de
  `.claude/skills/` descartados para não gerar links quebrados.
* **RF7** — Dockerfile amplo hoje: além do ferramental original, inclui Codex CLI, Gemini CLI,
  Docker CLI (DooD), OpenSpec e `bubblewrap`, todos instalados globalmente antes do `USER app`.
* **RF13** — o `docker-compose.yml` passou a referenciar a imagem por `image:` em vez de buildar
  (`build:` comentado); `scripts/build-image-devcontainer.sh` (renomeado de `build-image.sh`, junto
  com `.devcontainer/Dockerfile` → `Dockerfile-devcontainer`) é o mecanismo primário de build, com
  dois modos: padrão baixa `.env.example`/`Dockerfile-devcontainer` do GitHub; `--local` usa os
  arquivos do projeto onde o script está.
* **`install.sh`/`install.ps1` atualizados para o novo nome/escopo**: `REPO_URL` e as URLs do
  cabeçalho passaram a apontar para `devcontainer-ai-cli` (nome do repositório no GitHub, igual ao
  nome do projeto); ambos os instaladores agora validam
  e copiam `.secrets.example` junto com `.env.example` (RF6/RF9), e o resumo final orienta a
  preencher `.env`/`.secrets` separadamente e a construir a imagem antes do "Reopen in Container".
  `install.ps1` continua não executado neste container (sem PowerShell disponível).

**Pendências conhecidas** — defeitos abertos; ao tocar nesses pontos, corrija na direção do PRD
(detalhado no PRD §11):

1. **Mount do socket Docker ausente**: o `Dockerfile-devcontainer` comenta que o cliente Docker fala com o
   daemon do host "pelo `/var/run/docker.sock` montado (ver `devcontainer.json`)", mas esse mount
   não existe em `devcontainer.json` hoje — o cliente `docker`/`docker compose` instalado (RF7)
   não tem daemon acessível até isso ser corrigido.
2. **`.devcontainer/devcontainer-lock.json` órfão**: travava a feature
   `ghcr.io/anthropics/devcontainer-features/claude-code`, que não é mais referenciada em
   `devcontainer.json` — Claude Code virou instalação via `npm` no `Dockerfile-devcontainer`. Decidir entre
   remover o arquivo ou reintroduzir o uso da feature antes de confiar nele.
3. **`.claude/settings.json` não existe** neste repositório, embora documentação anterior citasse
   hooks de bell (`Stop`/`Notification`) nele — confirmar se foi removido de propósito ou se
   precisa ser recriado antes de assumir que os hooks ainda rodam.
4. **Build da imagem não validado neste ambiente**: o daemon Docker não está acessível aqui (só o
   cliente), então nem `scripts/build-image-devcontainer.sh` (nenhum dos dois modos) nem um
   `docker compose up` foram executados de fato contra o `Dockerfile-devcontainer` atual (com os
   quatro CLIs de IA). Vale rodar um build real antes de publicar a
   imagem, especialmente para o Antigravity CLI — seu instalador roda um passo interno opaco
   (`agy install`) cujo comportamento sob root não foi verificável.
5. **Camada 2 do RF12 presa à stack de origem**: `3-create-agents.md` e `6-final-review.md`
   pressupõem Blazor Web App, .NET 10, Bootstrap, JSInterop e prerendering. Falta uma variante
   agnóstica em que o especialista de framework siga a stack do projeto. A camada 1 já é agnóstica.
6. **`sdd-reviewer.md` cita o projeto de origem** (Copa2026, ASP.NET Core + Blazor Server) na
   descrição do papel, embora o processo que ele executa não dependa de stack.
7. **`prompts/5-new-feature-script.md` está vazio** — o roteiro de nova funcionalidade nunca foi
   escrito. Os demais prompts numerados estão completos.

---

## 7. Limites de escopo

Fora da primeira versão (PRD §9): Dockerfile/compose de produção na raiz, instalação automática de
plugins/MCPs, suporte a `arm64`, testes automatizados dos instaladores, suporte a CLIs de IA além
dos quatro já integrados (Claude Code, Codex CLI, Gemini CLI, Antigravity CLI). Não introduza esses
itens sem que o PRD mude antes.

`scripts/build-image-devcontainer.sh` (RF13) não viola esse limite: ele builda o
`Dockerfile-devcontainer` **que já existe** em `.devcontainer/`, não introduz um Dockerfile novo na
raiz.
