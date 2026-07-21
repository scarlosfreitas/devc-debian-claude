#!/usr/bin/env bash
set -euo pipefail

# install.sh — bootstrap do devc-debian-claude (Linux/macOS)
#
# Baixa o kit deste repositório, remove o .git do template, pergunta os dados
# do novo projeto (nome, nome do devcontainer, descrição), reescreve os
# arquivos afetados e inicializa um repositório git novo para o projeto.
#
# Uso recomendado (downloader avulso, sem clonar manualmente):
#   curl -fsSL https://raw.githubusercontent.com/scarlosfreitas/devc-debian-claude/main/install.sh | bash
#
# Modo não-interativo:
#   curl -fsSL .../install.sh | bash -s -- --name "Meu Projeto" --container "meu-projeto" \
#     --description "Descrição do projeto" --yes
#
# Ver --help para todas as opções.

REPO_URL="https://github.com/scarlosfreitas/devc-debian-claude.git"
BRANCH="main"
TARGET_DIR="."
PROJECT_NAME=""
CONTAINER_NAME=""
DESCRIPTION=""
ASSUME_YES=false
DO_PLUGINS=true
DO_COMMIT=true

usage() {
  cat <<'EOF'
Uso: install.sh [opções]

Opções:
  --dir <path>            Diretório de destino do novo projeto (padrão: .)
  --name <texto>          Nome do projeto
  --container <texto>     Nome do devcontainer/container
  --description <texto>   Descrição do projeto (vai para devcontainer.json)
  --repo-url <url>        URL do repositório do template (padrão: oficial)
  --branch <nome>         Branch do template a baixar (padrão: main)
  -y, --force, --yes      Não pede confirmação/prompts; usa padrões ou flags;
                           permite rodar em diretório não vazio
  --no-plugins            Pula o menu opcional de plugins
  --no-commit             Não cria o commit inicial (só roda git init)
  -h, --help              Mostra esta ajuda

Sem os flags de dados (--name/--container/--description), o script pergunta
interativamente. Em modo não interativo (sem terminal disponível) sem --yes,
o script aborta em vez de adivinhar os valores.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) TARGET_DIR="$2"; shift 2 ;;
    --name) PROJECT_NAME="$2"; shift 2 ;;
    --container) CONTAINER_NAME="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --repo-url) REPO_URL="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    -y|--force|--yes) ASSUME_YES=true; shift ;;
    --no-plugins) DO_PLUGINS=false; shift ;;
    --no-commit) DO_COMMIT=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'Aviso: %s\n' "$*" >&2; }
die()  { printf 'Erro: %s\n' "$*" >&2; exit 1; }

# Testa se /dev/tty pode de fato ser aberto para leitura — em ambientes sem
# terminal controlador (containers, CI, alguns modos de curl|bash) o arquivo
# existe e passa em "-r", mas abri-lo falha em runtime (ENXIO). Por isso
# tentamos abrir de verdade em vez de só checar o bit de permissão.
tty_available() {
  { exec 3</dev/tty; } 2>/dev/null || return 1
  exec 3<&-
  return 0
}

command -v git >/dev/null 2>&1 || die "git é obrigatório e não foi encontrado no PATH."

# --- diretório de destino -----------------------------------------------

mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [[ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
  if [[ "$ASSUME_YES" == true ]]; then
    warn "diretório '$TARGET_DIR' não está vazio; prosseguindo (--force)."
  elif tty_available; then
    reply=""
    read -r -p "Diretório '$TARGET_DIR' não está vazio. Continuar mesmo assim? [y/N] " reply < /dev/tty
    [[ "$reply" =~ ^[Yy]$ ]] || die "cancelado pelo usuário."
  else
    die "diretório '$TARGET_DIR' não está vazio. Rode novamente com --force para prosseguir."
  fi
fi

# --- baixa o kit e remove o .git do template -----------------------------

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

log "baixando o kit ($REPO_URL, branch $BRANCH)..."
git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR"
rm -rf "$TMP_DIR/.git"

log "copiando arquivos para '$TARGET_DIR'..."
cp -a "$TMP_DIR"/. "$TARGET_DIR"/

cd "$TARGET_DIR"

# --- coleta de dados do novo projeto -------------------------------------

esc_json() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
esc_sed_repl() { printf '%s' "$1" | sed -e 's/[&/\]/\\&/g'; }
slugify() {
  printf '%s' "$1" \
    | { iconv -t ascii//TRANSLIT 2>/dev/null || cat; } \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

prompt_default() {
  local __var="$1" __message="$2" __default="$3" __current __value
  __current="${!__var}"
  if [[ -n "$__current" ]]; then return 0; fi
  if [[ "$ASSUME_YES" == true ]]; then
    printf -v "$__var" '%s' "$__default"
    return 0
  fi
  if tty_available; then
    __value=""
    read -r -p "$__message [$__default]: " __value < /dev/tty
    printf -v "$__var" '%s' "${__value:-$__default}"
  else
    warn "terminal não interativo; usando padrão para \"$__message\": $__default"
    printf -v "$__var" '%s' "$__default"
  fi
}

DEFAULT_NAME="$(basename "$TARGET_DIR")"
prompt_default PROJECT_NAME "Nome do projeto" "$DEFAULT_NAME"

DEFAULT_CONTAINER="$(slugify "$PROJECT_NAME")"
prompt_default CONTAINER_NAME "Nome do devcontainer/container" "$DEFAULT_CONTAINER"

prompt_default DESCRIPTION "Descrição do projeto" "Ambiente de desenvolvimento padrão deste projeto."

# remove quebras de linha acidentais nos valores coletados
PROJECT_NAME="${PROJECT_NAME//$'\n'/ }"
CONTAINER_NAME="${CONTAINER_NAME//$'\n'/ }"
DESCRIPTION="${DESCRIPTION//$'\n'/ }"
CONTAINER_SLUG="$(slugify "$CONTAINER_NAME")"
[[ -n "$CONTAINER_SLUG" ]] || CONTAINER_SLUG="$DEFAULT_CONTAINER"

# --- reescreve devcontainer.json -----------------------------------------

log "atualizando .devcontainer/devcontainer.json..."
NAME_JSON="$(esc_sed_repl "$(esc_json "$PROJECT_NAME")")"
DESC_JSON="$(esc_sed_repl "$(esc_json "$DESCRIPTION")")"
sed -i.bak \
  -e "s/\"name\": \"Debian + Claude Code\"/\"name\": \"$NAME_JSON\"/" \
  -e "s/\"description\": \"Ambiente de desenvolvimento padrão deste projeto\.\"/\"description\": \"$DESC_JSON\"/" \
  .devcontainer/devcontainer.json
rm -f .devcontainer/devcontainer.json.bak

# --- gera o .env a partir do .env.example --------------------------------

log "gerando .devcontainer/.env..."
cp .devcontainer/.env.example .devcontainer/.env
sed -i.bak \
  -e "s/^DOCKER_IMAGE_NAME=.*/DOCKER_IMAGE_NAME=$CONTAINER_SLUG/" \
  -e "s/^DOCKER_IMAGE_TAG=.*/DOCKER_IMAGE_TAG=0.1/" \
  -e "s/^CONTAINER_NAME=.*/CONTAINER_NAME=$CONTAINER_SLUG/" \
  .devcontainer/.env
rm -f .devcontainer/.env.bak

# --- README.md do novo projeto -------------------------------------------

log "gerando README.md do projeto..."
cat > README.md <<EOF
# $PROJECT_NAME

$DESCRIPTION

## Ambiente de desenvolvimento

Este projeto usa um devcontainer Debian com Claude Code pré-instalado.

1. Abra a pasta no VS Code.
2. \`Ctrl+Shift+P\` → **Dev Containers: Reopen in Container**.
3. Faça login no Claude Code (no chat e no terminal).

Gerado a partir do template [devc-debian-claude](https://github.com/scarlosfreitas/devc-debian-claude).
EOF

# --- remove artefatos que só fazem sentido no template --------------------

log "removendo artefatos do template..."
rm -f PRD.md install.sh install.ps1

# --- menu opcional de plugins ---------------------------------------------

PLUGIN_BLOCK=""
if [[ "$DO_PLUGINS" == true ]]; then
  if [[ "$ASSUME_YES" == true && -z "${FORCE_PLUGIN_SELECTION:-}" ]]; then
    log "menu de plugins pulado (--yes); veja scripts/plugins.sh para instalar manualmente depois."
  elif ! tty_available; then
    warn "terminal não interativo; menu de plugins pulado. Veja scripts/plugins.sh."
  else
    echo
    echo "Plugins opcionais (instalados na próxima criação do container, via postCreate.sh):"
    echo "  [1] agent-browser   — automação de navegador"
    echo "  [2] Context7        — plugin MCP de documentação"
    echo "  [3] context-mode    — plugin MCP de contexto"
    echo "Informe os números desejados separados por espaço (Enter para nenhum):"
    read -r -p "> " selection < /dev/tty || true
    for opt in $selection; do
      case "$opt" in
        1) PLUGIN_BLOCK+=$'\nsudo npm install -g --allow-scripts=agent-browser agent-browser\nagent-browser install --with-deps\nnpx skills add vercel-labs/agent-browser' ;;
        2) PLUGIN_BLOCK+=$'\nclaude plugin install context7@claude-plugins-official --scope user' ;;
        3) PLUGIN_BLOCK+=$'\nclaude plugin marketplace add mksglu/context-mode\nclaude plugin install context-mode@context-mode --scope user' ;;
        *) warn "opção ignorada: $opt" ;;
      esac
    done
  fi
fi

if [[ -n "$PLUGIN_BLOCK" ]]; then
  log "gravando plugins escolhidos em .devcontainer/postCreate.sh..."
  BLOCK_CONTENT="# Instalação selecionada durante o bootstrap:$PLUGIN_BLOCK"
  awk -v block="$BLOCK_CONTENT" '
    /^# >>> devc-debian-claude: plugins selecionados/ { print; print block; skip=1; next }
    /^# <<< devc-debian-claude: plugins selecionados/ { skip=0 }
    !skip { print }
  ' .devcontainer/postCreate.sh > .devcontainer/postCreate.sh.new
  mv .devcontainer/postCreate.sh.new .devcontainer/postCreate.sh
  chmod +x .devcontainer/postCreate.sh
fi

# --- git init --------------------------------------------------------------

log "inicializando repositório git..."
git init --quiet
if [[ "$DO_COMMIT" == true ]]; then
  git add -A
  git commit --quiet -m "chore: bootstrap a partir do template devc-debian-claude"
fi

# --- resumo -----------------------------------------------------------------

echo
log "projeto '$PROJECT_NAME' criado em '$TARGET_DIR'."
echo "Próximos passos:"
echo "  1. Abra a pasta no VS Code."
echo "  2. Ctrl+Shift+P -> Dev Containers: Reopen in Container."
echo "  3. Faça login no Claude Code (chat e terminal)."
