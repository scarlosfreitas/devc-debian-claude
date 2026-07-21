# CLAUDE.md

Orientações para o Claude Code trabalhar neste repositório.

## O que é este repositório

`devc-debian-claude` é um **template/esqueleto** para iniciar projetos novos com um devcontainer
Debian + Claude Code pré-instalado. Veja [`PRD.md`](PRD.md) para o documento de produto completo
e [`README.md`](README.md) para o uso do bootstrap (`install.sh`/`install.ps1`).

> Se você está trabalhando dentro de um projeto **gerado** a partir deste template (não no
> template em si), este arquivo já deve ter sido adaptado ao contexto do novo projeto — a fonte
> de verdade do produto passa a ser o `.claude/PRD.md` local, não o `PRD.md` da raiz (que só
> existe no template e é removido pelo instalador).

## Estrutura relevante

- `.devcontainer/` — Dockerfile, `docker-compose.yml`, `devcontainer.json`, `postCreate.sh`,
  `.env.example`. Infra de **desenvolvimento**; Dockerfile/compose de produção vivem na raiz do
  projeto gerado, quando existirem.
- `.claude/agents/` — os 5 subagentes do ciclo `plan → run → test` (ver abaixo).
- `.claude/plans/` — planos registrados pelos agentes `plan-dev`/`plan-ops` antes da execução.
- `.claude/skills/` — skills reutilizáveis do Claude Code (ponto de extensão).
- `.claude/PRD.md` — PRD do projeto que será construído a partir deste kit (preencha ao iniciar
  um projeto novo; os agentes o tratam como fonte de verdade do produto).
- `scripts/clean.sh` — remove containers/volumes do devcontainer deste projeto.
- `scripts/plugins.sh` — catálogo de plugins/MCP instaláveis sob demanda.

## Ciclo de agentes (`plan → run → test`)

Dois trilhos, sem que um agente invoque o outro — a orquestração é do agente principal/usuário:

- **Trilha de código:** `plan-dev` (arquitetura + testes que falham, TDD) → `run-dev`
  (implementação) → `test-ops` (QA independente).
- **Trilha de infra:** `plan-ops` (planejamento somente leitura) → `run-ops` (execução).

Regras que valem para todos:
- Cada agente respeita estritamente seu papel (ver a descrição/restrições em cada arquivo de
  agente); não invente escopo além do que foi pedido.
- Todo plano de `plan-dev`/`plan-ops` é registrado em `.claude/plans/AAAA-MM-DD-{dev|ops}-<assunto>.md`
  antes de seguir para execução — atualize o arquivo existente em vez de duplicar.
- Ambiguidade de especificação volta para quem planejou, nunca é decidida por quem executa.

## Convenções gerais

- Português é o idioma padrão de documentação e commits deste repositório.
- Scripts shell seguem `set -euo pipefail` e o padrão `-y`/`--force` para pular confirmações
  (ver `scripts/clean.sh` e `install.sh` como referência).
- Locale UTF-8 (`LANG`/`LC_ALL=C.UTF-8`) é forçado no devcontainer para evitar problemas com
  acentuação (`ç`, `'`); preserve isso ao gerar/editar arquivos.
