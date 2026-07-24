#!/usr/bin/env pwsh
<#
.SYNOPSIS
  install.ps1 — bootstrap do devc-debian-claude (Windows/PowerShell).

.DESCRIPTION
  Baixa o kit deste repositório, remove o .git do template, pergunta os dados
  do novo projeto (nome, nome do devcontainer, descrição), reescreve os
  arquivos afetados e inicializa um repositório git novo para o projeto.

.EXAMPLE
  # Downloader avulso, totalmente interativo:
  irm https://raw.githubusercontent.com/scarlosfreitas/devc-debian-claude/main/install.ps1 | iex

.EXAMPLE
  # Não-interativo, via variáveis de ambiente (necessário ao usar "irm | iex",
  # que não aceita parâmetros de linha de comando):
  $env:INSTALL_NAME = "Meu Projeto"
  $env:INSTALL_CONTAINER = "meu-projeto"
  $env:INSTALL_DESCRIPTION = "Descrição do meu projeto"
  $env:INSTALL_YES = "1"
  irm .../install.ps1 | iex

.EXAMPLE
  # Baixado localmente, com parâmetros normais:
  .\install.ps1 -Name "Meu Projeto" -ContainerName "meu-projeto" -Description "..." -Yes
#>
param(
  [string]$Name = $env:INSTALL_NAME,
  [string]$ContainerName = $env:INSTALL_CONTAINER,
  [string]$Description = $env:INSTALL_DESCRIPTION,
  [string]$Dir = $(if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { "." }),
  [string]$RepoUrl = $(if ($env:INSTALL_REPO_URL) { $env:INSTALL_REPO_URL } else { "https://github.com/scarlosfreitas/devc-debian-claude.git" }),
  [string]$Branch = $(if ($env:INSTALL_BRANCH) { $env:INSTALL_BRANCH } else { "main" }),
  [switch]$Yes = [bool]$env:INSTALL_YES,
  [switch]$NoCommit = [bool]$env:INSTALL_NO_COMMIT
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "==> $msg" }
function Write-Warn2($msg) { Write-Warning $msg }
function Fail($msg) { Write-Host "Erro: $msg" -ForegroundColor Red; exit 1 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Fail "git é obrigatório e não foi encontrado no PATH."
}

function Read-HostOrDefault([string]$Message, [string]$Default) {
  # Read-Host lança erro em hosts não interativos (ex.: pipelines de CI); nesse
  # caso caímos no valor padrão em vez de travar o script.
  try {
    $value = Read-Host "$Message [$Default]"
  } catch {
    Write-Warn2 "terminal não interativo; usando padrão para `"$Message`": $Default"
    return $Default
  }
  if ([string]::IsNullOrWhiteSpace($value)) { return $Default } else { return $value }
}

function Prompt-Default([string]$Current, [string]$Message, [string]$Default) {
  if (-not [string]::IsNullOrWhiteSpace($Current)) { return $Current }
  if ($Yes) { return $Default }
  return Read-HostOrDefault -Message $Message -Default $Default
}

function Slugify([string]$Text) {
  $normalized = $Text.ToLowerInvariant().Normalize([System.Text.NormalizationForm]::FormD)
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $normalized.ToCharArray()) {
    $cat = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
    if ($cat -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($ch) }
  }
  $slug = [System.Text.RegularExpressions.Regex]::Replace($sb.ToString(), '[^a-z0-9]+', '-')
  return $slug.Trim('-')
}

# --- diretório de destino -------------------------------------------------

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Dir = (Resolve-Path $Dir).Path

$existing = Get-ChildItem -Force -Path $Dir -ErrorAction SilentlyContinue
if ($existing) {
  if ($Yes) {
    Write-Warn2 "diretório '$Dir' não está vazio; prosseguindo (-Yes)."
  } else {
    $reply = $null
    try { $reply = Read-Host "Diretório '$Dir' não está vazio. Continuar mesmo assim? [y/N]" }
    catch { Fail "diretório '$Dir' não está vazio. Rode novamente com -Yes para prosseguir." }
    # Cast explícito para string: "$null -notmatch ..." não retorna $false como se
    # esperaria (é um caso especial do operador -match/-notmatch em PowerShell) e
    # deixaria essa checagem de segurança passar aberta em modo não interativo.
    if ([string]$reply -notmatch '^[Yy]') { Fail "cancelado pelo usuário." }
  }
}

# --- baixa o kit e remove o .git do template ------------------------------

$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("devc-debian-claude-" + [System.Guid]::NewGuid().ToString("N"))

try {
  Write-Step "baixando o kit ($RepoUrl, branch $Branch)..."
  git clone --quiet --depth 1 --branch $Branch $RepoUrl $TmpDir
  if ($LASTEXITCODE -ne 0) { Fail "falha ao clonar $RepoUrl (branch $Branch)." }
  Remove-Item -Recurse -Force (Join-Path $TmpDir ".git")

  Write-Step "copiando arquivos para '$Dir'..."
  Get-ChildItem -Force -Path $TmpDir | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $Dir -Recurse -Force
  }
} finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $TmpDir
}

Set-Location $Dir

# --- coleta de dados do novo projeto --------------------------------------

$DefaultName = Split-Path -Leaf $Dir
$Name = Prompt-Default -Current $Name -Message "Nome do projeto" -Default $DefaultName

$DefaultContainer = Slugify $Name
$ContainerName = Prompt-Default -Current $ContainerName -Message "Nome do devcontainer/container" -Default $DefaultContainer

$Description = Prompt-Default -Current $Description -Message "Descrição do projeto" -Default "Ambiente de desenvolvimento padrão deste projeto."

$ContainerSlug = Slugify $ContainerName
if ([string]::IsNullOrWhiteSpace($ContainerSlug)) { $ContainerSlug = $DefaultContainer }

# --- reescreve devcontainer.json (JSON de verdade, não regex) -------------

Write-Step "atualizando .devcontainer/devcontainer.json..."
$dcPath = Join-Path $Dir ".devcontainer/devcontainer.json"
$dc = Get-Content -Raw -Path $dcPath | ConvertFrom-Json
$dc.name = $Name
if ($dc.PSObject.Properties.Name -contains 'description') {
  $dc.description = $Description
} else {
  $dc | Add-Member -NotePropertyName description -NotePropertyValue $Description
}
# Nota: o round-trip ConvertFrom-Json/ConvertTo-Json pode reordenar chaves;
# o JSON resultante continua válido, só muda a formatação cosmética.
($dc | ConvertTo-Json -Depth 10) | Set-Content -Path $dcPath -Encoding utf8

# --- gera o .env a partir do .env.example ----------------------------------

Write-Step "gerando .devcontainer/.env..."
$envExamplePath = Join-Path $Dir ".devcontainer/.env.example"
$envPath = Join-Path $Dir ".devcontainer/.env"
$envLines = Get-Content -Path $envExamplePath | ForEach-Object {
  if ($_ -match '^DOCKER_IMAGE_NAME=') { "DOCKER_IMAGE_NAME=$ContainerSlug" }
  elseif ($_ -match '^DOCKER_IMAGE_TAG=') { "DOCKER_IMAGE_TAG=0.1" }
  elseif ($_ -match '^CONTAINER_NAME=') { "CONTAINER_NAME=$ContainerSlug" }
  else { $_ }
}
($envLines -join "`n") + "`n" | Set-Content -Path $envPath -Encoding utf8 -NoNewline

# --- README.md do novo projeto ---------------------------------------------

Write-Step "gerando README.md do projeto..."
$readmePath = Join-Path $Dir "README.md"
@"
# $Name

$Description

## Ambiente de desenvolvimento

Este projeto usa um devcontainer Debian com Claude Code pré-instalado.

1. Abra a pasta no VS Code.
2. ``Ctrl+Shift+P`` -> **Dev Containers: Reopen in Container**.
3. Faça login no Claude Code (no chat e no terminal).

Gerado a partir do template [devc-debian-claude](https://github.com/scarlosfreitas/devc-debian-claude).
"@ | Set-Content -Path $readmePath -Encoding utf8

# --- esqueleto de PRD do projeto-alvo ---------------------------------------

Write-Step "gerando .claude/PRD.md (esqueleto do projeto)..."
$claudeDir = Join-Path $Dir ".claude"
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null }
$prdPath = Join-Path $claudeDir "PRD.md"
$prdBody = @'
# PRD — __PROJECT_NAME__

> Documento de produto (fonte de verdade) do **seu projeto**, gerado a partir do template
> [devc-debian-claude](https://github.com/scarlosfreitas/devc-debian-claude). Os subagentes em
> `.claude/agents/` (`plan-dev`, `run-dev`, `test-ops`, `plan-ops`, `run-ops`) tratam este
> arquivo como fonte de verdade — preencha-o antes de acionar o ciclo `plan -> run -> test`.
>
> Define **o quê** e **o porquê**; não descreve **como** o código é feito (isso é
> `docs/standards/`) nem regra de negócio (isso é `docs/domain/`). Apague este aviso conforme
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
'@
$prdBody = $prdBody -replace '__PROJECT_NAME__', $Name
Set-Content -Path $prdPath -Value $prdBody -Encoding utf8

# --- remove artefatos que só fazem sentido no template ----------------------

Write-Step "removendo artefatos do template..."
Remove-Item -Force -ErrorAction SilentlyContinue -Path (Join-Path $Dir "install.sh"), (Join-Path $Dir "install.ps1")

# --- git init ------------------------------------------------------------------

Write-Step "inicializando repositório git..."
git init --quiet
if ($LASTEXITCODE -ne 0) { Fail "git init falhou." }
if (-not $NoCommit) {
  git add -A
  git commit --quiet -m "chore: bootstrap a partir do template devc-debian-claude"
}

# --- resumo ----------------------------------------------------------------------

Write-Host ""
Write-Step "projeto '$Name' criado em '$Dir'."
Write-Host "Próximos passos:"
Write-Host "  1. Abra a pasta no VS Code."
Write-Host "  2. Ctrl+Shift+P -> Dev Containers: Reopen in Container."
Write-Host "  3. Faça login no Claude Code (chat e terminal)."
Write-Host "  4. Preencha .claude/PRD.md e STATUS.md antes de acionar o ciclo plan -> run -> test."
