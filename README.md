# devc-debian-claude

**Esqueleto (template) para iniciar projetos novos já com um Devcontainer Debian + Claude Code, scripts utilitários, um catálogo de plugins e uma trilha de subagentes `plan → run → test`.**

O objetivo é sair do zero para um ambiente de desenvolvimento padronizado em **um único comando**, sem repetir a montagem manual da base a cada projeto novo.

> 📄 O que este kit é e para onde ele evolui está descrito em [`.claude/PRD.md`](.claude/PRD.md). A
> metodologia e a arquitetura de pastas de referência estão em [`docs/guidelines/prd-good-pratices.md`](docs/guidelines/prd-good-pratices.md).

---

## 🚀 Início rápido (bootstrap em 1 comando)

Rode o instalador **dentro de uma pasta vazia** onde o novo projeto deve nascer. Ele baixa o kit, remove tudo que referencia este repositório, pergunta os dados do seu projeto e entrega um repositório git novo pronto para abrir no devcontainer.

**Linux / macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/scarlosfreitas/devc-debian-claude/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/scarlosfreitas/devc-debian-claude/main/install.ps1 | iex
```

O instalador vai perguntar:
- **Nome do projeto**
- **Nome do devcontainer/container**
- **Descrição do projeto**

E então: baixa o kit → apaga o `.git` do template → reescreve `.devcontainer/devcontainer.json` e gera o `.env` a partir do `.env.example` → **sobrescreve este `README.md`** por um README novo e mínimo do seu projeto → **regenera `.claude/PRD.md`** como esqueleto limpo do seu projeto → roda `git init` → remove da raiz o que só faz sentido no template (os próprios `install.*`).

### Modo não-interativo (CI/automação)

**Linux/macOS** — flags de linha de comando:
```bash
curl -fsSL .../install.sh | bash -s -- \
  --name "Meu Projeto" --container "meu-projeto" \
  --description "Descrição do meu projeto" --yes
```

**Windows** — `irm | iex` não aceita argumentos, então use variáveis de ambiente:
```powershell
$env:INSTALL_NAME = "Meu Projeto"
$env:INSTALL_CONTAINER = "meu-projeto"
$env:INSTALL_DESCRIPTION = "Descrição do meu projeto"
$env:INSTALL_YES = "1"
irm https://raw.githubusercontent.com/scarlosfreitas/devc-debian-claude/main/install.ps1 | iex
```

Depois de rodar:
1. Abra a pasta no VS Code → `Ctrl+Shift+P` → **Dev Containers: Reopen in Container**.
2. No container, faça login no Claude Code (no chat e no terminal).

---

## 📦 O que você recebe

- **Devcontainer Debian** (`debian:bookworm-slim`) com **Node.js LTS**, **git**, **Google Chrome** (para automação de navegador) e usuário não-root `app`.
- **Claude Code pré-instalado** via a feature oficial `ghcr.io/anthropics/devcontainer-features/claude-code`, com a pasta `~/.claude` do host montada por bind mount em `/home/app/.claude` (config, plugins, credenciais e memória compartilhados com o host).
- **Locale UTF-8** configurado (`LANG`/`LC_ALL=C.UTF-8`) para evitar problemas com acentuação (`ç`, `'`).
- **5 subagentes** formando o ciclo `plan → run → test` (ver abaixo).
- **Scripts utilitários** de limpeza e um catálogo de plugins.

---

## 🗂️ Estrutura

```
.
├── .devcontainer/
│   ├── Dockerfile            # imagem de desenvolvimento (Debian + Node + Chrome)
│   ├── docker-compose.yml    # service "app", parametrizado por .env
│   ├── devcontainer.json     # feature claude-code, bind mount de ~/.claude do host, locale UTF-8
│   ├── postCreate.sh         # setup pós-criação do container
│   └── .env.example          # DOCKER_IMAGE_NAME / DOCKER_IMAGE_TAG / CONTAINER_NAME
├── .claude/
│   ├── agents/               # plan-dev, plan-ops, run-dev, run-ops, test-ops
│   ├── plans/                # planos registrados pelos agentes (convenção de nomes)
│   ├── skills/               # ponto de extensão para skills do Claude Code
│   ├── PRD.md                # documento de produto (o quê/porquê) — fonte de verdade
│   └── settings.json         # hooks (bell ao terminar/notificar)
├── docs/
│   ├── domain/               # regras de negócio (fonte única da verdade do domínio)
│   ├── standards/            # padrões de arquitetura (architecture.md) e estilo (style.md)
│   └── guidelines/           # diretrizes da IA + prd-good-pratices.md (referência p/ o PRD)
├── src/                      # código de produção
├── test/                     # testes (TDD) que validam src/
├── scripts/
│   ├── clean.sh              # remove containers/volumes deste devcontainer
│   └── plugins.sh            # catálogo de plugins/MCP para instalar sob demanda
├── install.sh / install.ps1  # bootstrap (removidos no projeto gerado)
├── STATUS.md                 # ponto de partida: estado atual e próxima prioridade
└── README.md                 # este arquivo
```

---

## 🤖 Trilha de agentes (`plan → run → test`)

Dois trilhos independentes, sem que um agente invoque o outro — a orquestração é feita por você/pelo agente principal. Todos usam o `.claude/PRD.md` do seu projeto como fonte de verdade.

| Agente | Papel | Modelo |
|---|---|---|
| **plan-dev** | Arquiteto TDD: desenha contratos e escreve os **testes que falham**. Não escreve código funcional. | opus |
| **run-dev** | Implementa o código funcional **estritamente** para os testes passarem. | sonnet |
| **test-ops** | QA independente: valida o run-dev contra a spec do plan-dev. Nunca corrige o código. | sonnet |
| **plan-ops** | Planeja infra (**somente leitura**): produz o passo a passo com os comandos exatos. | opus |
| **run-ops** | Executa o plano de infra do plan-ops. Único perfil autorizado a modificar o ambiente. | sonnet |

Os planos ficam registrados em [`.claude/plans/`](.claude/plans/) seguindo a convenção `AAAA-MM-DD-{dev|ops}-<assunto>.md`.

---

## 🧩 Plugins (opcional)

Para manter o container enxuto, **nada é instalado automaticamente**. O arquivo [`scripts/plugins.sh`](scripts/plugins.sh) é um catálogo do que você pode instalar sob demanda (agent-browser, Context7, context-mode).

---

## 🧹 Limpeza do ambiente

Para remover o container e os volumes **deste** devcontainer (preservando o volume compartilhado `vscode`):

```bash
bash scripts/clean.sh        # pede confirmação
bash scripts/clean.sh -y     # sem confirmação
```

---

## 🛠️ Uso manual (sem o instalador)

Se preferir não usar o `install.sh`/`install.ps1`:

```bash
git clone https://github.com/scarlosfreitas/devc-debian-claude.git
mv -- devc-debian-claude/{*,.[!.]*,..?*} .
rmdir devc-debian-claude
```
Depois: ajuste o `name` em `.devcontainer/devcontainer.json`, crie o `.env` a partir do `.env.example`, apague a pasta `.git` e rode `git init`.

---

## 🔧 Evoluindo o template

Este repositório continua evoluindo de forma independente — melhorias aqui beneficiam todos os projetos futuros. Contribuições bem-vindas: preencher o `postCreate.sh`, adicionar skills em `.claude/skills/`, ampliar o catálogo de `scripts/plugins.sh` e refinar os agentes.
