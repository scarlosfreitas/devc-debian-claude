#!/usr/bin/env bash
set -euo pipefail

# install.sh — bootstrap do devc-debian-claude (Linux/macOS)
#
# Baixa o kit deste repositório, remove o .git do template, pergunta os dados
# do novo projeto (nome e descrição), reescreve os arquivos afetados e
# inicializa um repositório git novo para o projeto.
#
# O nome do devcontainer/container NÃO é perguntado: ele é derivado do nome do
# projeto (RF2 do PRD).
#
# Uso recomendado (downloader avulso, sem clonar manualmente):
#   curl -fsSL https://raw.githubusercontent.com/scarlosfreitas/devc-debian-claude/main/install.sh | bash
#
# Modo não-interativo:
#   curl -fsSL .../install.sh | bash -s -- --name "Meu Projeto" \
#     --description "Descrição do projeto" --yes
#
# Ver --help para todas as opções.

REPO_URL="https://github.com/scarlosfreitas/devc-debian-claude.git"
BRANCH="main"
TARGET_DIR="."
PROJECT_NAME=""
DESCRIPTION=""
PROJECT_FOLDER=""
ASSUME_YES=false
DO_COMMIT=true

usage() {
  cat <<'EOF'
Uso: install.sh [opções]

Opções:
  --dir <path>            Diretório de destino do novo projeto (padrão: .)
  --name <texto>          Nome do projeto
  --description <texto>   Descrição do projeto (vai para devcontainer.json)
  --project-folder <path> Caminho absoluto do projeto, usado como PROJECT_FOLDER
                           em .devcontainer/.env e como workspaceFolder em
                           .devcontainer/devcontainer.json (padrão: o diretório
                           de destino)
  --repo-url <url>        URL do repositório do template (padrão: oficial)
  --branch <nome>         Branch do template a baixar (padrão: main)
  -y, --force, --yes      Não pede confirmação/prompts; usa padrões ou flags;
                           permite rodar em diretório não vazio
  --no-commit             Não cria o commit inicial (só roda git init)
  -h, --help              Mostra esta ajuda

O nome do devcontainer/container não é perguntado: é derivado do nome do
projeto (espaços viram "-" e o texto vai para minúsculas).

Sem os flags de dados (--name/--description/--project-folder), o script
pergunta interativamente. Em modo não interativo (sem terminal disponível) sem
--yes, o script aborta em vez de adivinhar os valores.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) TARGET_DIR="$2"; shift 2 ;;
    --name) PROJECT_NAME="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --project-folder) PROJECT_FOLDER="$2"; shift 2 ;;
    --repo-url) REPO_URL="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    -y|--force|--yes) ASSUME_YES=true; shift ;;
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
# Lista FECHADA do RF6: só estes itens vão para o projeto gerado. O que não
# estiver aqui (README.md, CLAUDE.md, .claude/PRD.md, .claude/settings.local.json,
# .agents/skills/, ...) fica só no template.
# valida tudo antes de copiar qualquer coisa, para não deixar o destino pela metade
for d in .claude .devcontainer prompts scripts; do
  [[ -d "$TMP_DIR/$d" ]] || die "item obrigatório ausente no template: $d/"
done
for f in .env.example .gitignore skills-lock.json; do
  [[ -f "$TMP_DIR/$f" ]] || die "item obrigatório ausente no template: $f"
done

for d in .claude .devcontainer prompts scripts; do
  mkdir -p "$TARGET_DIR/$d"
  cp -a "$TMP_DIR/$d/." "$TARGET_DIR/$d/"
done
for f in .env.example .gitignore skills-lock.json; do
  cp -a "$TMP_DIR/$f" "$TARGET_DIR/$f"
done

# .claude/ é copiado exceto estes dois: o PRD é regerado como esqueleto mais
# abaixo, e o settings.local.json do template desativaria skills no projeto novo.
rm -f "$TARGET_DIR/.claude/PRD.md" "$TARGET_DIR/.claude/settings.local.json"

# .claude/skills/ é um conjunto de symlinks para .agents/skills/, que NÃO é
# copiado (RF10: as skills são materializadas sob demanda no projeto novo).
# Sem isso o projeto nasceria com links quebrados.
if [[ -d "$TARGET_DIR/.claude/skills" ]]; then
  find "$TARGET_DIR/.claude/skills" -maxdepth 1 -type l ! -exec test -e {} \; -delete
  rmdir "$TARGET_DIR/.claude/skills" 2>/dev/null || true
fi

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

prompt_default DESCRIPTION "Descrição do projeto" "Ambiente de desenvolvimento padrão deste projeto."

# RF3: o mesmo caminho absoluto no host e dentro do container. O padrão é a
# pasta de instalação; o usuário pode informar outro valor, mas ele será usado
# nos DOIS lugares (PROJECT_FOLDER e workspaceFolder), nunca em só um.
prompt_default PROJECT_FOLDER "Caminho do projeto no host e no container" "$TARGET_DIR"

# remove quebras de linha acidentais nos valores coletados
PROJECT_NAME="${PROJECT_NAME//$'\n'/ }"
DESCRIPTION="${DESCRIPTION//$'\n'/ }"
PROJECT_FOLDER="${PROJECT_FOLDER//$'\n'/ }"

[[ "$PROJECT_FOLDER" = /* ]] || die "o caminho do projeto deve ser absoluto: '$PROJECT_FOLDER'."

# RF2: o nome do container é derivado do nome do projeto, não perguntado.
CONTAINER_SLUG="$(slugify "$PROJECT_NAME")"
[[ -n "$CONTAINER_SLUG" ]] || CONTAINER_SLUG="$(slugify "$DEFAULT_NAME")"
[[ -n "$CONTAINER_SLUG" ]] || die "não foi possível derivar um nome de container a partir de '$PROJECT_NAME'."

# --- reescreve devcontainer.json -----------------------------------------

log "atualizando .devcontainer/devcontainer.json..."
# Reescreve por linha (em vez de casar o valor antigo) para não depender do
# conteúdo que veio do template: tudo que vier depois de "name": / "description":
# / "workspaceFolder": é substituído. O arquivo é JSONC (tem comentários), então
# não passamos por um parser JSON — os comentários precisam sobreviver.
#
# Os valores chegam pelo ambiente (ENVIRON), e não por "awk -v": o -v reprocessa
# sequências de escape, o que desfaria o escape de aspas/barras do esc_json.
DC_NAME="$(esc_json "$PROJECT_NAME")" \
DC_DESC="$(esc_json "$DESCRIPTION")" \
DC_FOLDER="$(esc_json "$PROJECT_FOLDER")" \
awk '
  BEGIN { name = ENVIRON["DC_NAME"]; desc = ENVIRON["DC_DESC"]; folder = ENVIRON["DC_FOLDER"] }
  # "description" é reemitido logo após "name"; descarta o que já existir.
  /^[[:space:]]*"description"[[:space:]]*:/ { next }
  /^[[:space:]]*"name"[[:space:]]*:/ && !seen_name {
    seen_name = 1
    printf "  \"name\": \"%s\",\n", name
    printf "  \"description\": \"%s\",\n", desc
    next
  }
  /^[[:space:]]*"workspaceFolder"[[:space:]]*:/ && !seen_folder {
    seen_folder = 1
    printf "  \"workspaceFolder\": \"%s\",\n", folder
    next
  }
  { print }
  END {
    if (!seen_name)   { print "ERRO: chave \"name\" não encontrada" > "/dev/stderr"; exit 1 }
    if (!seen_folder) { print "ERRO: chave \"workspaceFolder\" não encontrada" > "/dev/stderr"; exit 1 }
  }
' .devcontainer/devcontainer.json > .devcontainer/devcontainer.json.new \
  || die "falha ao reescrever devcontainer.json."
mv .devcontainer/devcontainer.json.new .devcontainer/devcontainer.json

# --- gera o .env a partir do .env.example --------------------------------

log "gerando .devcontainer/.env..."
cp .devcontainer/.env.example .devcontainer/.env
# PROJECT_FOLDER precisa ser idêntico ao workspaceFolder acima (RF3): o
# docker-compose monta o projeto nesse caminho dentro do container.
sed -i.bak \
  -e "s/^DOCKER_IMAGE_NAME=.*/DOCKER_IMAGE_NAME=$(esc_sed_repl "$CONTAINER_SLUG")/" \
  -e "s/^DOCKER_IMAGE_TAG=.*/DOCKER_IMAGE_TAG=0.1/" \
  -e "s/^CONTAINER_NAME=.*/CONTAINER_NAME=$(esc_sed_repl "$CONTAINER_SLUG")/" \
  -e "s/^PROJECT_FOLDER=.*/PROJECT_FOLDER=$(esc_sed_repl "$PROJECT_FOLDER")/" \
  .devcontainer/.env
rm -f .devcontainer/.env.bak
grep -q "^PROJECT_FOLDER=" .devcontainer/.env \
  || printf '\nPROJECT_FOLDER=%s\n' "$PROJECT_FOLDER" >> .devcontainer/.env

# --- esqueleto de PRD do projeto-alvo -------------------------------------

log "gerando .claude/PRD.md (esqueleto do projeto)..."
mkdir -p .claude
cat > .claude/PRD.md <<EOF
# PRD — $PROJECT_NAME

> Documento de produto (fonte de verdade) do **seu projeto**, gerado a partir do template
> [devc-debian-claude](https://github.com/scarlosfreitas/devc-debian-claude). Os subagentes em
> \`.claude/agents/\` (\`plan-dev\`, \`run-dev\`, \`test-ops\`, \`plan-ops\`, \`run-ops\`) tratam este
> arquivo como fonte de verdade — preencha-o antes de acionar o ciclo \`plan → run → test\`.
>
> Define **o quê** e **o porquê**; não descreve **como** o código é feito (isso é
> \`docs/standards/\`) nem regra de negócio (isso é \`docs/domain/\`). Apague este aviso conforme
> for preenchendo.

## 1. Visão geral e propósito

O que este projeto é, o problema que resolve e o resultado esperado.

## 2. Público-alvo e casos de uso

Quem usa, e os principais cenários de uso.

## 3. Estado atual / contexto técnico

Stack, dependências, integrações e o que já existe (se for um projeto em andamento).

## 4. Requisitos funcionais

Lista de funcionalidades, uma seção por funcionalidade (RF1, RF2, ...), com comportamento
esperado e casos de borda relevantes o suficiente para virarem testes.

## 5. Requisitos não-funcionais

Performance, segurança, portabilidade, garantias de integridade de dados, etc.

## 6. Fora de escopo

O que este projeto explicitamente não vai fazer (por ora).

## 7. Critérios de aceite

Checklist verificável do que precisa ser verdade para considerar o projeto (ou uma
funcionalidade) pronto.
EOF

# Nada a remover aqui: a cópia acima já é a lista fechada do RF6 — os itens que
# só fazem sentido no template nunca chegam ao projeto gerado. Os instaladores
# em scripts/ são copiados de propósito (scripts/ vai inteiro).

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
echo "  container:      $CONTAINER_SLUG"
echo "  PROJECT_FOLDER: $PROJECT_FOLDER (igual ao workspaceFolder)"
echo "Próximos passos:"
echo "  1. Copie .env.example para .env e preencha suas credenciais git."
echo "  2. Abra a pasta no VS Code."
echo "  3. Ctrl+Shift+P -> Dev Containers: Reopen in Container."
echo "  4. Faça login no Claude Code (chat e terminal)."
echo "  5. Preencha .claude/PRD.md."
