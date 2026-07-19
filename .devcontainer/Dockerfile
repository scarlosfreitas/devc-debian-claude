# Infra de DESENVOLVIMENTO (o Dockerfile/compose de produção virão na raiz).
# Imagem base derivada de Debian, enxuta e estável.
FROM debian:bookworm-slim

# --- Pacotes do sistema -------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        curl \
        git \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# --- Usuário não-root (UID/GID 1000, casa com o fallback do docker-compose) ---
RUN groupadd --gid 1000 app \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash app

# Pré-cria o diretório de config do Claude Code com dono correto: quando o
# devcontainer monta um volume nomeado vazio em /home/app/.claude pela
# primeira vez, o Docker copia o conteúdo/dono deste diretório da imagem
# para o volume. Sem isso, o ponto de montagem é criado como root e o
# usuário app fica sem permissão de escrita.
RUN mkdir -p /home/app/.claude && chown -R app:app /home/app/.claude

# Volta para o usuário padrão não-root do container por segurança
USER app

WORKDIR /workspace

