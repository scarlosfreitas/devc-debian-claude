# PRD — Projeto de layout de devcontainer com claude

> Documento de produto (fonte de verdade) deste repositório. Define **o quê** e **o porquê**.
> Escrito segundo práticas de Spec Driven Development: cada requisito funcional é declarado com
> `SHALL` e acompanhado de cenários verificáveis (`WHEN` / `THEN`), de modo que o PRD possa ser
> convertido em testes sem interpretação adicional.
>
> **Estado do documento:** artefatos que a documentação antiga do repositório citava mas que não
> existem (`.claude/plans/`, `docs/`, `src/`, `test/`, `STATUS.md`) foram movidos para
> *Evoluções futuras* (§11). O que está nas seções 1 a 9 corresponde ao que existe hoje ou ao que
> foi explicitamente decidido. `.claude/agents/` passou a existir e é coberto pelo RF12.

---

## 1. Visão Geral

`devc-debian-claude` é um **esqueleto (template) de projeto** que entrega um ambiente de
desenvolvimento e prototipação já montado: um Devcontainer baseado em Debian, com Claude Code
instalado, ferramentas de desenvolvimento (Node.js LTS, npm, `uv`, Bun, `git`, `gh`, `sudo`,
Google Chrome) e um catálogo de skills e plugins prontos para serem habilitados.

O entregável central do projeto é um **script instalador simples** que, executado dentro da pasta
onde o novo projeto deve nascer, baixa tudo o que é necessário e deixa um repositório git novo
pronto para ser aberto no devcontainer — sem que o usuário precise repetir manualmente a montagem
da base a cada projeto.

Uma restrição estrutural atravessa todo o produto: **a pasta de instalação, o `workspaceFolder`
do devcontainer e o `PROJECT_FOLDER` usado pelo `docker-compose.yml` devem ser o mesmo caminho
absoluto**. Isso garante que o Claude Code enxergue o projeto sob o mesmo caminho no host e dentro
do container, mantendo continuidade de configuração, memória e sessões entre os dois ambientes.

---

## 2. Objetivos

Sair do zero para um ambiente de desenvolvimento padronizado em um único comando, de forma
reprodutível e sem passos manuais escondidos.

* Fornecer um instalador de um comando (`scripts/install.sh` para Linux/macOS e
  `scripts/install.ps1` para Windows) que baixe o kit, colete os dados do novo projeto e entregue
  um repositório git inicializado.
* Garantir paridade de caminho entre host e container, derivando `workspaceFolder` e
  `PROJECT_FOLDER` do diretório de instalação (`pwd`), de modo que o Claude Code opere sobre o
  mesmo caminho absoluto nos dois ambientes.
* Entregar uma imagem de desenvolvimento enxuta e estável (Debian bookworm-slim) com as
  ferramentas de desenvolvimento e prototipação já instaladas e usuário não-root.
* Compartilhar a configuração do Claude Code do host com o container (bind mount de `~/.claude`),
  preservando credenciais, plugins e memória entre rebuilds.
* Manter skills e plugins **declarados mas não impostos**: instalados/versionados no template e
  desativáveis por projeto, para não poluir o container com o que aquele projeto não usa.

---

## 3. Público-alvo

* Desenvolvedor que inicia projetos novos com frequência e não quer remontar a base a cada vez.
* Usuário de Claude Code que quer o mesmo ambiente e a mesma configuração no host e no container.
* Desenvolvedor de dados/infra que se beneficia do catálogo de skills já versionado (Docker,
  Postgres, Kafka, Dagster, Proxmox, Azure, MCP).
* Times que precisam de um ambiente de desenvolvimento reprodutível entre máquinas Linux, macOS e
  Windows.

---

## 4. Fluxo principal

O produto não tem interface gráfica; a "navegação" é a sequência de comandos do fluxo de bootstrap.

**Fluxo de instalação (caminho feliz):**

1. O usuário cria/escolhe a pasta onde o projeto deve nascer e entra nela.
2. Executa o instalador (`scripts/install.sh` ou `scripts/install.ps1`), de forma interativa ou
   com flags/variáveis de ambiente.
3. O instalador pergunta: **nome do projeto** e **descrição**. O nome informado tem os espaços
   substituídos por `-` e é convertido para minúsculas, e o resultado é usado também como nome do
   devcontainer/container — não há pergunta separada para o nome do container.
4. O instalador baixa o kit, remove o `.git` do template, copia **apenas** os itens da lista de
   instalação (RF6), reescreve `.devcontainer/devcontainer.json`, gera `.devcontainer/.env` a
   partir do `.devcontainer/.env.example`, roda `git init` e cria o commit inicial. O
   `.claude/PRD.md` **não** é copiado nem regerado — o projeto nasce sem PRD, a ser escrito pelo
   usuário (`prompts/1-create-prd.md`).
5. O usuário preenche o `.env` da raiz com suas credenciais git (a partir de `.env.example`).
6. O usuário abre a pasta no VS Code e escolhe **Dev Containers: Reopen in Container**.
7. O `postCreate.sh` recria, dentro do container, as credenciais git (`~/.git-credentials`) e o
   `GH_TOKEN` da `gh` CLI a partir do `.env` da raiz.
8. O usuário faz login no Claude Code e começa a trabalhar.

**Fluxo de desenvolvimento no projeto gerado (SDD — ver RF12):**

1. Os prompts numerados de `prompts/` são executados na ordem: `1-create-prd` → `2-create-claude`
   → `3-create-agents` → `4-create-readme`.
2. `/opsx:propose` do OpenSpec gera a change (`proposal.md`, `design.md`, `tasks.md`, `specs/`).
3. O subagente `sdd-reviewer`, guiado pela skill `sdd-review`, revisa a change e conclui
   *Pronto para Apply* ou *Requer ajustes antes do Apply* — neste caso, volta ao passo 2.
4. `/opsx:apply` implementa a change.
5. Ao fim de um ciclo de evolução, `prompts/6-final-review.md` aciona os subagentes
   `review-architect`, `review-performance`, `review-blazor` e `review-ui`, consolidados pelo
   `review-manager` em `docs/reviews/review-AAAA-MM-DD.md`.
6. A seção *Próximos Passos* desse consolidado vira a base do próximo `/opsx:propose` (passo 2).

**Fluxo de manutenção:**

* `scripts/plugins.sh` — catálogo de plugins/MCPs a instalar sob demanda.
* `scripts/install-skill.sh` — catálogo de skills instaláveis via `npx skills`.
* `scripts/clean.sh` — remove o container e os volumes deste devcontainer.

---

## 5. Requisitos funcionais

### RF1 — Bootstrap por um comando

O instalador **SHALL** baixar o template, descartar o histórico git do template e entregar um
repositório git novo inicializado na pasta de destino.

* **Cenário: pasta vazia**
  * **WHEN** o instalador é executado em uma pasta vazia
  * **THEN** o kit é clonado com `--depth 1` na branch configurada, o `.git` do template é removido,
    os arquivos são copiados para o destino, `git init` é executado e um commit inicial é criado.
* **Cenário: pasta não vazia sem confirmação**
  * **WHEN** a pasta de destino não está vazia e o modo não-interativo está ativo sem `--yes`/`-Yes`
  * **THEN** o instalador aborta com erro em vez de sobrescrever arquivos.
* **Cenário: `--no-commit`**
  * **WHEN** o instalador é executado com `--no-commit`/`-NoCommit`
  * **THEN** `git init` é executado, mas nenhum commit inicial é criado.

### RF2 — Coleta de dados do projeto

O instalador **SHALL** coletar **nome do projeto** e **descrição**, por prompt interativo, por
flags de linha de comando (Linux/macOS) ou por variáveis de ambiente (Windows). O nome do
devcontainer/container **SHALL** ser derivado do nome do projeto, e não perguntado separadamente.

* **Cenário: normalização do nome**
  * **WHEN** o usuário informa `Meu Projeto Novo` como nome do projeto
  * **THEN** o nome passa a ser `meu-projeto-novo` (espaços substituídos por `-` e todo o texto em
    minúsculas) e esse mesmo valor é usado como nome do devcontainer/container.
* **Cenário: interativo**
  * **WHEN** há terminal disponível e os valores não foram passados por flag
  * **THEN** o instalador pergunta cada valor oferecendo um padrão (nome da pasta de destino como
    nome do projeto).
* **Cenário: não-interativo**
  * **WHEN** não há terminal disponível e `--yes`/`INSTALL_YES` está ativo
  * **THEN** o instalador usa os valores das flags/variáveis e, na ausência delas, os padrões,
    sem bloquear a execução.
* **Cenário: ausência de opção para o nome do container**
  * **WHEN** o instalador é executado, interativa ou não-interativamente
  * **THEN** não existe pergunta, flag (`--container`) nem variável (`INSTALL_CONTAINER`) para o
    nome do container; as opções de dados são apenas `--name`/`INSTALL_NAME`,
    `--description`/`INSTALL_DESCRIPTION` e `--project-folder`/`INSTALL_PROJECT_FOLDER`.

### RF3 — Paridade de caminho entre host e container

O instalador **SHALL** coletar do usuário um único caminho absoluto de projeto — oferecendo como
padrão o diretório de instalação (`pwd`, ou equivalente no Windows) — e gravá-lo **nos dois
lugares**: `PROJECT_FOLDER` (em `.devcontainer/.env`) e `workspaceFolder` (em
`.devcontainer/devcontainer.json`). O valor é coletado por prompt interativo, por
`--project-folder` (Linux/macOS) ou por `INSTALL_PROJECT_FOLDER` (Windows).

* **Cenário: padrão (pasta de instalação)**
  * **WHEN** o instalador roda em `/caminho/do/projeto` e o usuário aceita o padrão
  * **THEN** `PROJECT_FOLDER=/caminho/do/projeto` e `workspaceFolder` recebe o mesmo valor,
    fazendo o bind mount do `docker-compose.yml` expor o projeto sob o caminho idêntico ao do host.
* **Cenário: caminho informado pelo usuário**
  * **WHEN** o usuário informa `/code/app-x`
  * **THEN** `PROJECT_FOLDER=/code/app-x` **e** `workspaceFolder="/code/app-x"` — o mesmo valor,
    nunca em só um dos dois arquivos.
* **Cenário: caminho relativo**
  * **WHEN** o valor informado não começa com `/`
  * **THEN** o instalador aborta com erro, pois o bind mount exige caminho absoluto.
* **Cenário: divergência**
  * **WHEN** `PROJECT_FOLDER` e `workspaceFolder` divergem
  * **THEN** a instalação é considerada inválida, pois o Claude Code deixa de reconhecer o mesmo
    projeto no host e no container.

### RF4 — Geração do `.devcontainer/.env`

O instalador **SHALL** copiar `.devcontainer/.env.example` para `.devcontainer/.env` e atualizar
`DOCKER_IMAGE_NAME` e `CONTAINER_NAME` com o nome do projeto normalizado (RF2), além de
`PROJECT_FOLDER` conforme o RF3.

* **Cenário: nome com espaços e maiúsculas**
  * **WHEN** o nome informado é `Meu Projeto Novo`
  * **THEN** `DOCKER_IMAGE_NAME=meu-projeto-novo` e `CONTAINER_NAME=meu-projeto-novo`.

### RF5 — Personalização do `devcontainer.json`

O instalador **SHALL** reescrever `name`, `description` e `workspaceFolder` em
`.devcontainer/devcontainer.json` com os dados coletados, **substituindo tudo o que vier depois da
chave** (`"name":`, `"description":`, `"workspaceFolder":`) em vez de casar o valor antigo,
preservando o JSON válido e os comentários do arquivo (JSONC).

* **Cenário: valor anterior desconhecido**
  * **WHEN** o `name` do template é qualquer texto
  * **THEN** a linha inteira é reescrita como `"name": "<nome informado>",`, sem depender de qual
    era o valor anterior.
* **Cenário: `description` ausente**
  * **WHEN** o `devcontainer.json` do template não tem a chave `description`
  * **THEN** o instalador a acrescenta logo após `name`, com a descrição informada.
* **Cenário: comentários**
  * **WHEN** a reescrita termina
  * **THEN** os comentários `//` do `devcontainer.json` continuam presentes e o arquivo segue
    válido como JSONC.
* **Cenário: chave obrigatória ausente**
  * **WHEN** `name` ou `workspaceFolder` não existem no arquivo
  * **THEN** o instalador aborta com erro, em vez de gerar um `devcontainer.json` incompleto.

### RF6 — Itens copiados para o projeto gerado

O instalador **SHALL** copiar para o projeto gerado **apenas** os itens abaixo, e nada além deles
(lista fechada — o que não estiver aqui não é instalado):

| Item | Observação |
|---|---|
| `.claude/` | **exceto** `settings.local.json`, `PRD.md` e os symlinks de `.claude/skills/` |
| `.devcontainer/` | diretório completo |
| `prompts/` | diretório completo |
| `scripts/` | diretório completo |
| `.env.example` | arquivo da raiz |
| `.gitignore` | arquivo da raiz |
| `skills-lock.json` | arquivo da raiz |

* **Cenário: projeto recém-gerado**
  * **WHEN** a instalação termina
  * **THEN** existem exatamente os itens da lista acima, e nada além disso.
* **Cenário: itens não instalados**
  * **WHEN** a instalação termina
  * **THEN** não existem no projeto gerado o `README.md` do template, o `.claude/PRD.md` do
    template, o `.claude/settings.local.json` do template nem o diretório `.agents/skills/`.
* **Cenário: PRD não é regerado**
  * **WHEN** a instalação termina
  * **THEN** `.claude/PRD.md` **não existe** no projeto gerado — não é copiado o do template, e o
    instalador **não** cria nenhum esqueleto em seu lugar. O PRD do projeto novo é escrito pelo
    usuário, a partir de `prompts/1-create-prd.md`.
* **Cenário: instaladores no projeto gerado**
  * **WHEN** a instalação termina
  * **THEN** `scripts/` está presente por inteiro, incluindo `install.sh` e `install.ps1`, por
    `scripts/` ser copiado como diretório completo.
* **Cenário: validação antes da cópia**
  * **WHEN** falta algum item obrigatório da lista no template baixado
  * **THEN** o instalador aborta **antes** de copiar qualquer coisa, sem deixar o destino pela
    metade.
* **Cenário: symlinks de skills**
  * **WHEN** a instalação termina
  * **THEN** não existem links simbólicos quebrados no projeto gerado — os symlinks de
    `.claude/skills/` apontam para `.agents/skills/`, que não é copiado (RF10), e por isso são
    descartados junto com o diretório `.claude/skills/` quando este fica vazio.

### RF7 — Ambiente do container

A imagem de desenvolvimento **SHALL** fornecer Debian bookworm-slim com Node.js LTS + npm, `uv`,
Bun, `git`, `gh`, `sudo`, utilitários de arquivo (`zip`/`unzip`/`xz-utils`), Google Chrome,
`ccusage`, `claude-usage`, locale UTF-8 e o usuário não-root `app` (UID/GID 1000).

* **Cenário: escrita no workspace**
  * **WHEN** o container sobe com `user: ${HOST_UID:-1000}:${HOST_GID:-1000}`
  * **THEN** o usuário `app` escreve no workspace montado sem erro de permissão.
* **Cenário: ferramentas no PATH do usuário do container**
  * **WHEN** o usuário `app` executa `node`, `npm`, `uv`, `bun`, `git`, `gh`, `sudo`, `ccusage` ou
    `claude-usage`
  * **THEN** todos respondem pelo PATH, sem "command not found".
* **Cenário: instalações em `$HOME`**
  * **WHEN** a imagem instala ferramentas que gravam em `$HOME` (Bun em `$HOME/.bun`,
    `uv tool install` em `$HOME/.local/bin`)
  * **THEN** essas instalações rodam **como o usuário `app`** (após o `USER app`), de modo que os
    binários caiam em `/home/app/...` — que é o que o `ENV PATH` declara — e não em `/root/...`;
    o `ENV PATH` é declarado **antes** dessas instalações para que elas não emitam aviso de
    diretório fora do PATH.

### RF8 — Configuração do Claude Code compartilhada com o host

O devcontainer **SHALL** montar `~/.claude` do host em `/home/app/.claude` por bind mount e
definir `CLAUDE_CONFIG_DIR=/home/app/.claude`.

* **Cenário: rebuild do container**
  * **WHEN** o container é recriado
  * **THEN** configuração, plugins, credenciais e memória do Claude Code permanecem disponíveis,
    por residirem no host.

### RF9 — Credenciais git e `GH_TOKEN` dentro do container

O `postCreate.sh` **SHALL** recriar, a cada criação do container, `~/.git-credentials` e o export
de `GH_TOKEN` a partir do `.env` da raiz do projeto, resolvendo a raiz pelo próprio caminho do
script (independente do nome da pasta).

* **Cenário: `.env` presente e completo**
  * **WHEN** existem `GIT_USERNAME` e `GIT_TOKKEN` no `.env` da raiz
  * **THEN** `~/.git-credentials` é escrito com permissão `600` (usuário url-encoded) e
    `~/.gh_token_env` é criado e carregado pelo `~/.bashrc`.
* **Cenário: `.env` ausente ou incompleto**
  * **WHEN** o `.env` não existe ou as variáveis não estão definidas
  * **THEN** o passo é pulado com mensagem informativa e o `postCreate` termina com sucesso.
* **Cenário: helper de credenciais**
  * **WHEN** o container sobe
  * **THEN** `credential.helper=store` prevalece (via `GIT_CONFIG_*` e
    `dev.containers.copyGitConfig: false`), impedindo que o helper do host quebre push/commit.

### RF10 — Catálogo de skills e plugins sob demanda

O template **SHALL** versionar as skills instaladas (`skills-lock.json` + `.agents/skills/`) e
permitir desativá-las por projeto, e **SHALL NOT** instalar plugins/MCPs automaticamente.

* **Cenário: skill não desejada**
  * **WHEN** uma skill é marcada como `off` em `.claude/settings.local.json`
  * **THEN** ela permanece versionada no repositório, mas não é ativada na sessão.
* **Cenário: skills no projeto gerado**
  * **WHEN** a instalação termina
  * **THEN** o projeto recebe o `skills-lock.json` (declaração das skills) e o
    `scripts/install-skill.sh`, mas **não** o conteúdo de `.agents/skills/` — as skills desejadas
    são materializadas sob demanda no projeto novo.
* **Cenário: overrides do template**
  * **WHEN** a instalação termina
  * **THEN** o `.claude/settings.local.json` do template não é copiado, de modo que o projeto novo
    começa sem skills desativadas herdadas.

### RF11 — Limpeza do ambiente

`scripts/clean.sh` **SHALL** remover o container e os volumes deste devcontainer, preservando o
volume compartilhado `vscode`.

* **Cenário: execução com confirmação**
  * **WHEN** `bash scripts/clean.sh` é executado
  * **THEN** os alvos são listados e a remoção só ocorre após confirmação (`-y`/`--force` pula).
* **Cenário: nada a remover**
  * **WHEN** não há container nem volume correspondente
  * **THEN** o script informa e termina com sucesso.

### RF12 — Trilha de revisão Spec-Driven Development

O template **SHALL** entregar duas camadas de revisão independentes, que atuam em momentos
distintos do ciclo SDD e **SHALL NOT** modificar arquivos — o produto de ambas é um relatório.

**Camada 1 — revisão da change, entre o `/opsx:propose` e o `/opsx:apply`.** Composta pela skill
`sdd-review` (processo) e pelo subagente `sdd-reviewer` (executor). Revisa os artefatos da change,
não o código.

* **Cenário: posição no ciclo**
  * **WHEN** uma change foi proposta por `/opsx:propose` e o desenvolvedor sinaliza intenção de
    seguir para o `/opsx:apply`
  * **THEN** o `sdd-reviewer` é acionado antes do Apply, lendo `proposal.md`, `design.md`,
    `tasks.md`, `specs/` e o `CLAUDE.md` do projeto como única fonte de verdade.
* **Cenário: etapas do processo**
  * **WHEN** o `sdd-reviewer` executa
  * **THEN** ele percorre as seis etapas da skill `sdd-review`: Consistência, Escopo, Arquitetura,
    Implementação, Banco de Dados e Riscos.
* **Cenário: relatório e veredito**
  * **WHEN** a revisão termina
  * **THEN** o relatório traz **Pontos Positivos**, **Problemas Encontrados**, **Recomendações** e
    uma **Conclusão** binária: *Pronto para Apply* ou *Requer ajustes antes do Apply*, com arquivo
    e seção exatos de cada problema.
* **Cenário: revisor somente leitura**
  * **WHEN** o `sdd-reviewer` identifica um erro de correção trivial
  * **THEN** ele registra o problema com a localização e **não** o corrige — dispõe apenas de
    `Read`, `Grep` e `Glob`, com `Write`, `Edit`, `NotebookEdit` e `Bash` negados, preservando a
    independência da revisão.

**Camada 2 — revisão final do projeto, entre ciclos de evolução.** Subagentes `review-architect`,
`review-performance`, `review-blazor`, `review-ui` e `review-manager`, criados pelo prompt
`prompts/3-create-agents.md` e acionados pelo `prompts/6-final-review.md`. Revisa o projeto
implementado, muito além do código: arquitetura, desempenho, ciclo de vida do framework, UX e
acessibilidade.

* **Cenário: independência entre especialistas**
  * **WHEN** um especialista identifica um problema fora da sua área
  * **THEN** ele apenas o menciona como observação, sem emitir recomendação a respeito, e não
    assume responsabilidade de outro especialista.
* **Cenário: consolidação**
  * **WHEN** os quatro especialistas concluem seus relatórios
  * **THEN** o `review-manager` — que não analisa código — elimina duplicatas, agrupa semelhantes,
    identifica conflitos e prioriza, **sem reinterpretar nem modificar** as conclusões técnicas.
* **Cenário: saída do consolidado**
  * **WHEN** o `review-manager` conclui
  * **THEN** exibe um resumo executivo no terminal e grava o relatório em
    `docs/reviews/review-AAAA-MM-DD.md`, com as seções Resumo Executivo, Arquitetura, Performance,
    Blazor, Interface do Usuário, Plano Priorizado e Próximos Passos.
* **Cenário: realimentação do ciclo**
  * **WHEN** o consolidado é produzido
  * **THEN** a seção *Próximos Passos* propõe como organizar as melhorias em uma nova change do
    OpenSpec, servindo de base para o `/opsx:propose` seguinte.
* **Cenário: adequação de stack**
  * **WHEN** o projeto gerado não usa Blazor Web App / .NET 10 / Bootstrap
  * **THEN** os prompts da camada 2 precisam ser adaptados antes de gerar os agentes (o
    `review-blazor` substituído pelo equivalente da stack), pois foram escritos para ASP.NET Core
    + Blazor; a camada 1 é agnóstica de stack.

---

## 6. Requisitos não-funcionais

* **Portabilidade:** o bootstrap funciona em Linux, macOS (bash) e Windows (PowerShell).
* **Idempotência:** `postCreate.sh` pode rodar novamente sem duplicar entradas no `~/.bashrc`.
* **Segurança:** o container roda como usuário não-root; segredos ficam em arquivos com permissão
  `600`; `.env` e `.devcontainer/.env` são ignorados pelo git.
* **Enxutez:** a imagem instala apenas o necessário (`--no-install-recommends`, limpeza de
  `/var/lib/apt/lists`); plugins e MCPs não entram na imagem.
* **Reprodutibilidade:** versões de feature e skills são travadas
  (`devcontainer-lock.json`, `skills-lock.json`).
* **Localização:** mensagens dos scripts e documentação em português; locale `C.UTF-8` no container
  para acentuação correta.

---

## 7. Fonte de dados

Não há banco de dados nem carga de *seed*. As fontes de configuração do produto são:

* **`.env` (raiz)** — credenciais git do usuário (`GIT_USERNAME`, `GIT_EMAIL`, `GIT_NAME`,
  `GIT_TOKKEN`), a partir de `.env.example`. Consumido pelo `postCreate.sh`. Não versionado;
  preenchido pelo usuário.
* **`.devcontainer/.env`** — parâmetros da imagem e do container (`DOCKER_IMAGE_NAME`,
  `DOCKER_IMAGE_TAG`, `CONTAINER_NAME`, `PROJECT_FOLDER`), gerado pelo instalador a partir de
  `.devcontainer/.env.example`. Não versionado.
* **`skills-lock.json`** — origem, caminho e hash de cada skill instalada em `.agents/skills/`.
* **`.devcontainer/devcontainer-lock.json`** — versão resolvida da feature `claude-code`.
* **`.claude/settings.json` / `.claude/settings.local.json`** — hooks do Claude Code e overrides de
  ativação de skills por projeto.

---

## 8. Estrutura do projeto

Marcação: `[i]` = copiado para o projeto gerado pelo instalador (RF6); `[t]` = existe apenas no
template; `[g]` = gerado pelo instalador ou pelo uso, não versionado.

```text
devc-debian-claude/
    .devcontainer/              [i] diretório completo
        Dockerfile              < imagem Debian + Node/uv/Bun/gh/Chrome, usuário app
        docker-compose.yml      < service "app", parametrizado pelo .env
        devcontainer.json       < feature claude-code, bind mount de ~/.claude, locale UTF-8
        postCreate.sh           < credenciais git + GH_TOKEN a partir do .env da raiz
        devcontainer-lock.json  < versão travada da feature claude-code
        .env.example            < DOCKER_IMAGE_NAME / DOCKER_IMAGE_TAG / CONTAINER_NAME / PROJECT_FOLDER
        .env                    [g] gerado pelo instalador
    .claude/                    [i] exceto settings.local.json, PRD.md e skills/
        settings.json           [i] hooks (bell ao terminar/notificar)
        PRD.md                  [t] este documento; não copiado nem regerado no projeto gerado
        settings.local.json     [g] skills desativadas neste projeto (não versionado)
        skills/                 [t] symlinks para ../../.agents/skills/* (descartados na instalação)
            sdd-review/         < pasta real (não symlink): processo de revisão de change OpenSpec
        agents/                 [i] subagentes; hoje só sdd-reviewer.md (executor da sdd-review)
    .agents/                    [t] não copiado para o projeto gerado
        skills/                 < skills instaladas via npx skills (uma pasta por skill)
    scripts/                    [i] diretório completo
        install.sh              < bootstrap Linux/macOS
        install.ps1             < bootstrap Windows/PowerShell
        install-skill.sh        < catálogo de skills instaláveis
        plugins.sh              < catálogo de plugins/MCPs sob demanda
        clean.sh                < remove container e volumes deste devcontainer
    prompts/                    [i] diretório completo — numerados na ordem de uso
        1-create-prd.md         < gera este PRD
        2-create-claude.md      < gera o CLAUDE.md
        3-create-agents.md      < gera os subagentes review-* (camada 2 do RF12)
        4-create-readme.md      < gera o README.md
        5-new-feature-script.md < roteiro de nova funcionalidade (hoje vazio)
        6-final-review.md       < aciona os review-* e o review-manager (camada 2 do RF12)
    skills-lock.json            [i] lock das skills instaladas
    .env.example                [i] credenciais git (modelo)
    .gitignore                  [i]
    .env                        [g] credenciais git, preenchido pelo usuário
    CLAUDE.md                   [t] guia de trabalho no repositório; não copiado
    README.md                   [t] documentação pública do template; não copiado
```

---

## 9. Fora do escopo

Não faz parte da primeira versão:

* Infraestrutura de produção (Dockerfile/compose de produção na raiz).
* Instalação automática de plugins e MCPs no container.
* Suporte a arquiteturas diferentes de `amd64` (Chrome e `gh` são instalados com
  `arch=amd64` fixo).
* Testes automatizados dos instaladores.

---

## 10. Critérios de aceitação

* [ ] Rodar `scripts/install.sh` em uma pasta vazia produz um repositório git com commit inicial,
      sem qualquer referência ao `.git` do template.
* [ ] `scripts/install.ps1` produz o mesmo resultado no Windows.
* [ ] Em modo não-interativo com `--yes`/`INSTALL_YES`, a instalação conclui sem prompts.
* [ ] Em pasta não vazia e sem `--yes`, a instalação aborta sem sobrescrever arquivos.
* [ ] `PROJECT_FOLDER` em `.devcontainer/.env` é igual ao caminho informado (padrão: o `pwd` da
      instalação).
* [ ] `workspaceFolder` em `.devcontainer/devcontainer.json` é igual ao `PROJECT_FOLDER`, inclusive
      quando o usuário informa um caminho diferente da pasta de instalação.
* [ ] Um caminho de projeto relativo faz a instalação abortar.
* [ ] Informar `Meu Projeto Novo` como nome resulta em `DOCKER_IMAGE_NAME=meu-projeto-novo` e
      `CONTAINER_NAME=meu-projeto-novo`, sem pergunta separada para o nome do container.
* [ ] `name` e `description` em `devcontainer.json` refletem os dados informados, com JSON válido e
      com os comentários do arquivo preservados.
* [ ] O projeto gerado contém exatamente `.claude/`, `.devcontainer/`, `prompts/`, `scripts/`,
      `.env.example`, `.gitignore` e `skills-lock.json` — e nada além disso.
* [ ] O projeto gerado **não** contém `README.md`, `CLAUDE.md`, `.claude/settings.local.json`,
      `.claude/skills/` nem `.agents/`.
* [ ] `find <projeto> -xtype l` não retorna nenhum link simbólico quebrado.
* [ ] `.claude/PRD.md` **não existe** no projeto gerado — nem o do template, nem um esqueleto.
* [ ] "Reopen in Container" sobe o container, e dentro dele o projeto está no mesmo caminho
      absoluto do host.
* [ ] Dentro do container: `node`, `npm`, `uv`, `bun`, `git`, `gh`, `sudo`, `ccusage` e
      `claude-usage` respondem no PATH; `whoami` retorna `app`; `locale` retorna `C.UTF-8`.
* [ ] `/home/app/.claude` reflete o `~/.claude` do host e sobrevive a um rebuild.
* [ ] Com `.env` preenchido, `git push` e `gh auth status` funcionam dentro do container sem prompt
      interativo; sem `.env`, o `postCreate.sh` termina com sucesso e mensagem informativa.
* [ ] Rodar `postCreate.sh` duas vezes não duplica a linha de carregamento no `~/.bashrc`.
* [ ] As skills marcadas `off` em `.claude/settings.local.json` não são ativadas na sessão.
* [ ] `bash scripts/clean.sh -y` remove container e volumes do projeto e preserva o volume `vscode`.
* [ ] O projeto gerado contém `.claude/agents/sdd-reviewer.md` e `.claude/skills/sdd-review/`.
* [ ] Acionado sobre uma change com uma tarefa sem requisito correspondente, o `sdd-reviewer`
      reporta o problema com arquivo e seção, e conclui *Requer ajustes antes do Apply*.
* [ ] Ao final de uma execução do `sdd-reviewer`, `git status` não acusa nenhum arquivo modificado.
* [ ] `prompts/6-final-review.md` produz um único consolidado do `review-manager` em
      `docs/reviews/review-AAAA-MM-DD.md`, com as sete seções obrigatórias e todas as recomendações
      classificadas em Alta, Média ou Baixa prioridade.

---

## 11. Evoluções futuras

* Estrutura documental de referência: `docs/domain/`, `docs/standards/`, `docs/guidelines/`, além
  de `src/`, `test/` e `STATUS.md`.
* Alinhamento das URLs de download nos **cabeçalhos dos instaladores**, que ainda citam
  `.../main/install.sh` na raiz do repositório, enquanto os arquivos vivem em `scripts/` — o
  `README.md` já usa o caminho correto.
* **Generalização da camada 2 do RF12.** `prompts/3-create-agents.md` e `prompts/6-final-review.md`
  estão presos à stack de origem (Blazor Web App, .NET 10, Bootstrap, JSInterop, prerendering);
  precisam de uma variante agnóstica, em que o especialista de framework seja escolhido conforme a
  stack do projeto. Os subagentes `review-*` em si não são versionados no template — são gerados
  por prompt no projeto destino, e por isso `.claude/agents/` hoje contém apenas o `sdd-reviewer.md`.
* **Neutralização do `sdd-reviewer.md`**, cujo texto ainda cita o projeto de origem (Copa2026,
  ASP.NET Core + Blazor Server) na descrição do papel, embora o processo de revisão em si seja
  agnóstico de stack.
* Escrita do `prompts/5-new-feature-script.md`, hoje vazio.
* Preenchimento automático do `.env` da raiz pelo instalador, hoje manual por conter segredo.
* Suporte multiarquitetura (`arm64`) na imagem de desenvolvimento.
* Testes automatizados do bootstrap (`install.sh`/`install.ps1`) em CI.
* Seleção interativa de skills e plugins durante a instalação.
