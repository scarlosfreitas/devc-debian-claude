# Imagem de referência multiestágio (PRD RF13): mesmo ferramental de
# .devcontainer/Dockerfile, mas desacoplada de qualquer projeto — sem
# PROJECT_FOLDER, sem bind mount, sem premissa de workspace. Serve de base
# (FROM), local ou publicada em registry, para o devcontainer de projetos
# futuros. Mudança em um Dockerfile exige a mudança equivalente no outro
# (ver CLAUDE.md §5).

# ============================================================================
# Estágio 1/2 — tools: tudo que roda como root (pacotes de sistema, CLIs via
# apt/npm). Corresponde à parte de .devcontainer/Dockerfile anterior ao
# "USER app".
# ============================================================================
FROM debian:bookworm-slim AS tools

# --- Pacotes do sistema -------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gnupg \
        make \
        nano \
        sudo \
        zip \
        unzip \
        xz-utils \
        iputils-ping \
        iproute2 \
        bubblewrap \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js (LTS) + npm -------------------------------------------------------
# Repositório NodeSource configurado manualmente (mesmo padrão do Chrome/gh
# abaixo), em vez do script setup_lts.x: aquele script chama o binário "apt"
# internamente, que emite "WARNING: apt does not have a stable CLI interface"
# a cada rebuild. Usando só apt-get diretamente, o warning some.
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- Google Chrome (automação de navegador, ex.: agent-browser) ---------------
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# --- GitHub CLI (gh) -----------------------------------------------------------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# --- Docker CLI (DooD: cliente no container, daemon no host via socket) --------
# Apenas o cliente e o plugin do Compose — o daemon NÃO roda aqui; cada projeto
# que herdar desta imagem decide se monta /var/run/docker.sock do host.
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /usr/share/keyrings/docker.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# --- uv (gerenciador de dependências/ambiente Python do projeto) --------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# --- Usuário não-root (UID/GID 1000) ------------------------------------------
RUN groupadd --gid 1000 app \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash app \
    && groupadd -f docker \
    && usermod -aG docker app \
    && echo "app ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/app \
    && chmod 0440 /etc/sudoers.d/app

# Pré-cria os diretórios de config do Claude Code, Gemini e Codex com dono correto: quando um
# projeto que herdar desta imagem montar um volume nomeado vazio em /home/app/.claude, .gemini
# ou .codex pela primeira vez, o Docker copia o conteúdo/dono deste diretório da imagem para o
# volume. Sem isso, o ponto de montagem é criado como root e o usuário app fica sem permissão
# de escrita.
RUN mkdir -p /home/app/.claude /home/app/.gemini /home/app/.codex && chown -R app:app /home/app/.claude /home/app/.gemini /home/app/.codex

# --- ccusage (CLI de monitoramento de consumo de tokens Claude, via npm) ------
# Instalação global (/usr/lib/node_modules + /usr/bin), ainda como root.
RUN npm install -g ccusage

# --- OpenSpec (CLI de spec-driven development, comandos /opsx:*) --------------
# Instalação global, ainda como root.
RUN npm install -g @fission-ai/openspec

# --- Gemini CLI (Google) -------------------------------------------------------
# Instalação global, ainda como root. Usa o diretório /home/app/.gemini
# pré-criado acima para config/credenciais do usuário app.
RUN npm install -g @google/gemini-cli

# --- Claude Code CLI (Anthropic) ------------------------------------------------
# Instalação global, ainda como root. Usa o diretório /home/app/.claude
# pré-criado acima para config/credenciais do usuário app.
RUN npm install -g @anthropic-ai/claude-code

# --- Codex CLI (OpenAI) ---------------------------------------------------------
# Instalação global, ainda como root. Usa o diretório /home/app/.codex
# pré-criado acima para config/credenciais do usuário app.
RUN npm install -g @openai/codex

# ============================================================================
# Estágio 2/2 — final: tudo que roda como usuário app (PATH + instalações que
# gravam em $HOME). Corresponde à parte de .devcontainer/Dockerfile posterior
# ao "USER app". É este o estágio que projetos futuros herdam via FROM.
# ============================================================================
FROM tools AS final

# PATH do usuário app. Declarado ANTES das instalações abaixo porque tanto o
# instalador do Bun quanto o "uv tool install" avisam/erram quando o diretório
# de destino não está no PATH.
ENV PATH="/home/app/.bun/bin:/home/app/.local/bin:${PATH}"

# Volta para o usuário padrão não-root da imagem por segurança. Tudo daqui
# para baixo instala em $HOME — e $HOME precisa ser /home/app, não /root, senão
# os binários ficam fora do PATH (e sem permissão) para o usuário app.
USER app

# --- Bun (runtime/gerenciador JS) ----------------------------------------------
# Instala em $HOME/.bun => /home/app/.bun/bin.
RUN curl -fsSL https://bun.com/install | bash

# --- claude-usage (CLI de monitoramento de consumo de tokens, via uv tool) ----
# Instala em $HOME/.local/bin => /home/app/.local/bin.
RUN uv tool install git+https://github.com/phuryn/claude-usage

# --- Google Antigravity (AGY CLI) ---------------------------------------------
# Instala em $HOME/.local/bin => /home/app/.local/bin.
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

WORKDIR /workspace
