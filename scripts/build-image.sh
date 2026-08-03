#!/usr/bin/env bash
set -euo pipefail

# Constrói a imagem de referência multiestágio (Dockerfile na raiz, PRD RF13),
# usando nome e tag lidos do .env da raiz do projeto (BASE_IMAGE_NAME e
# BASE_IMAGE_TAG) — não confundir com DOCKER_IMAGE_NAME/DOCKER_IMAGE_TAG do
# .devcontainer/.env, que se referem à imagem do próprio devcontainer.
#
# Qualquer argumento extra é repassado ao "docker build" (ex.: --no-cache).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ENV_FILE="$PROJECT_DIR/.env"
DOCKERFILE="$PROJECT_DIR/Dockerfile"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Erro: $ENV_FILE não encontrado. Copie .env.example para .env e preencha BASE_IMAGE_NAME/BASE_IMAGE_TAG." >&2
  exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "Erro: $DOCKERFILE não encontrado. Este script constrói a imagem de referência do template (RF13), que não existe em projetos gerados a partir dele." >&2
  exit 1
fi

BASE_IMAGE_NAME="$(grep -E '^BASE_IMAGE_NAME=' "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"
BASE_IMAGE_TAG="$(grep -E '^BASE_IMAGE_TAG=' "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"

if [[ -z "$BASE_IMAGE_NAME" || -z "$BASE_IMAGE_TAG" ]]; then
  echo "Erro: BASE_IMAGE_NAME e BASE_IMAGE_TAG precisam estar definidos em $ENV_FILE." >&2
  exit 1
fi

IMAGE_REF="${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}"

echo "Construindo $IMAGE_REF a partir de $DOCKERFILE (estágio final)..."
docker build \
  -f "$DOCKERFILE" \
  -t "$IMAGE_REF" \
  --target final \
  "$@" \
  "$PROJECT_DIR"

echo "Imagem construída: $IMAGE_REF"
