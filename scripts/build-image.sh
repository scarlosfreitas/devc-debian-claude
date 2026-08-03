#!/usr/bin/env bash
set -euo pipefail

# Constrói a imagem do devcontainer (.devcontainer/Dockerfile) fora do
# docker-compose, usando nome e tag lidos de .devcontainer/.env
# (DOCKER_IMAGE_NAME e DOCKER_IMAGE_TAG — as mesmas variáveis que o
# docker-compose.yml usa). Serve para gerar/publicar essa imagem como base
# de referência em outros projetos, sem precisar subir o compose.
#
# Mesmo contexto de build do docker-compose.yml: raiz do projeto, com
# -f .devcontainer/Dockerfile. Qualquer argumento extra é repassado ao
# "docker build" (ex.: --no-cache).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ENV_FILE="$PROJECT_DIR/.devcontainer/.env"
DOCKERFILE="$PROJECT_DIR/.devcontainer/Dockerfile"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Erro: $ENV_FILE não encontrado. Copie .devcontainer/.env.example para .devcontainer/.env e preencha DOCKER_IMAGE_NAME/DOCKER_IMAGE_TAG." >&2
  exit 1
fi

DOCKER_IMAGE_NAME="$(grep -E '^DOCKER_IMAGE_NAME=' "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"
DOCKER_IMAGE_TAG="$(grep -E '^DOCKER_IMAGE_TAG=' "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"

if [[ -z "$DOCKER_IMAGE_NAME" || -z "$DOCKER_IMAGE_TAG" ]]; then
  echo "Erro: DOCKER_IMAGE_NAME e DOCKER_IMAGE_TAG precisam estar definidos em $ENV_FILE." >&2
  exit 1
fi

IMAGE_REF="${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"

echo "Construindo $IMAGE_REF a partir de $DOCKERFILE..."
docker build \
  -f "$DOCKERFILE" \
  -t "$IMAGE_REF" \
  "$@" \
  "$PROJECT_DIR"

echo "Imagem construída: $IMAGE_REF"
