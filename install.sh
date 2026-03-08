#!/bin/bash
# ================================================================
#  INSTALADOR OPENCLAW - macOS Apple Silicon Universal
#  Detecta automaticamente: M1 / M2 / M3 / M4
# ================================================================

# ── Cores ─────────────────────────────────────────────────────
GRN='\033[0;32m' CYN='\033[0;36m' YLW='\033[1;33m' RED='\033[0;31m' RST='\033[0m' BLD='\033[1m'
ok()   { echo -e "${GRN}[OK]${RST} $1"; }
info() { echo -e "${CYN}[..] $1${RST}"; }
warn() { echo -e "${YLW}[!!] $1${RST}"; }
fail() { echo -e "${RED}[XX] $1${RST}"; exit 1; }

# NÃO usar set -e — tratamos erros manualmente para dar mensagens claras
set -o pipefail

echo -e "\n${BLD}OpenClaw Installer — macOS Apple Silicon${RST}\n"

# ── Detecta hardware ──────────────────────────────────────────
chip_raw=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)
RAM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
CPU_TOTAL=$(sysctl -n hw.physicalcpu)
CPU_PERF=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo "$CPU_TOTAL")

if   echo "$chip_raw" | grep -q "M4"; then CHIP_GEN="M4"
elif echo "$chip_raw" | grep -q "M3"; then CHIP_GEN="M3"
elif echo "$chip_raw" | grep -q "M2"; then CHIP_GEN="M2"
else                                        CHIP_GEN="M1"; fi

if   [ "$CPU_TOTAL" -ge 24 ]; then CHIP_VARIANT="Ultra"
elif [ "$CPU_TOTAL" -ge 12 ]; then CHIP_VARIANT="Max"
elif [ "$CPU_TOTAL" -ge 10 ]; then CHIP_VARIANT="Pro"
else                                CHIP_VARIANT=""; fi

if   [ "$RAM_GB" -ge 64 ]; then OS_RESERVE=8
elif [ "$RAM_GB" -ge 32 ]; then OS_RESERVE=6
elif [ "$RAM_GB" -ge 16 ]; then OS_RESERVE=4
else                             OS_RESERVE=3; fi

NODE_HEAP_MB=$(( (RAM_GB - OS_RESERVE) * 1024 ))
PNPM_WORKERS=$(( CPU_PERF * 4 / 5 ))
[ "$PNPM_WORKERS" -lt 2 ] && PNPM_WORKERS=2

# --turbofan vai direto no exec node (nao é permitido em NODE_OPTIONS)
case "$CHIP_GEN" in
  M4) TURBOFAN="--turbofan"; SEMI_SPACE="--max-semi-space-size=256" ;;
  M3) TURBOFAN="--turbofan"; SEMI_SPACE="--max-semi-space-size=192" ;;
  M2) TURBOFAN="--turbofan"; SEMI_SPACE="--max-semi-space-size=128" ;;
  M1) TURBOFAN="";            SEMI_SPACE="--max-semi-space-size=64"  ;;
esac

echo -e "  Chip:  ${BLD}Apple ${CHIP_GEN}${CHIP_VARIANT}${RST}"
echo -e "  RAM:   ${BLD}${RAM_GB} GB${RST}  |  Heap Node.js: ${BLD}$(( NODE_HEAP_MB/1024 )) GB${RST}"
echo -e "  Cores: ${BLD}${CPU_TOTAL}${RST}       |  Workers pnpm: ${BLD}${PNPM_WORKERS}${RST}\n"

# ── 1. Verifica Xcode tools ───────────────────────────────────
info "Verificando Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
  fail "Xcode CLI nao encontrado. Execute: xcode-select --install — depois rode este script novamente."
fi
ok "Xcode CLI OK"

# ── 2. Verifica Homebrew ──────────────────────────────────────
info "Verificando Homebrew..."
if ! command -v brew &>/dev/null; then
  fail "Homebrew nao encontrado. Instale em https://brew.sh — depois rode este script novamente."
fi
ok "Homebrew OK"

# ── 3. nvm ────────────────────────────────────────────────────
info "Verificando nvm..."
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  info "Instalando nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  if [ ! -d "$NVM_DIR" ]; then
    fail "Falha ao instalar nvm. Verifique sua conexao e tente novamente."
  fi
fi

# Carrega nvm na sessão atual — CRÍTICO fazer antes de qualquer uso de node
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if ! command -v nvm &>/dev/null && ! type nvm &>/dev/null; then
  fail "nvm instalado mas nao carregou. Tente: source ~/.zshrc && bash install.sh"
fi
ok "nvm OK"

# ── 4. Node.js 22 ─────────────────────────────────────────────
info "Verificando Node.js..."
if command -v node &>/dev/null && [ "$(node --version | cut -d. -f1 | tr -d v)" -ge 22 ]; then
  ok "Node.js $(node --version) ja instalado"
else
  info "Instalando Node.js 22 via nvm..."
  nvm install 22 || fail "Falha ao instalar Node.js 22."
  nvm use 22
  nvm alias default 22
  ok "Node.js $(node --version) instalado"
fi

# Confirma que node está no PATH desta sessão
command -v node &>/dev/null || fail "Node.js instalado mas nao encontrado no PATH. Verifique o nvm."

# ── 5. pnpm ───────────────────────────────────────────────────
info "Verificando pnpm..."
if ! command -v pnpm &>/dev/null; then
  info "Instalando pnpm..."
  npm install -g pnpm || fail "Falha ao instalar pnpm."
fi
ok "pnpm $(pnpm --version) OK"

# ── 6. git ────────────────────────────────────────────────────
command -v git &>/dev/null || fail "Git nao encontrado. Execute: xcode-select --install"

# ── 7. Clone ──────────────────────────────────────────────────
INSTALL_DIR="$HOME/.openclaw/install/openclaw"
info "Clonando repositorio..."
rm -rf "$INSTALL_DIR"
mkdir -p "$HOME/.openclaw/install"
git clone --depth 1 https://github.com/openclaw/openclaw.git "$INSTALL_DIR" \
  || fail "Falha no git clone. Verifique sua conexao com a internet."
ok "Repositorio clonado"

# ── 8. Build ──────────────────────────────────────────────────
info "Instalando dependencias (pnpm install)..."
cd "$INSTALL_DIR"
PNPM_CONCURRENCY=$PNPM_WORKERS pnpm install \
  || fail "Falha no pnpm install. Verifique o log acima."

info "Compilando build (pnpm run build)..."
NODE_OPTIONS="--max-old-space-size=${NODE_HEAP_MB} ${SEMI_SPACE}" pnpm run build \
  || fail "Falha no pnpm run build. Verifique o log acima."

# Confirma que o dist foi gerado
if [ ! -f "$INSTALL_DIR/dist/entry.mjs" ] && [ ! -f "$INSTALL_DIR/dist/entry.js" ]; then
  fail "Build falhou — dist/entry.(m)js nao encontrado. Verifique os erros acima."
fi
ok "Build concluido"

# ── 9. Wrapper global ─────────────────────────────────────────
info "Criando comando global..."
mkdir -p "$HOME/.local/bin"
W_PATH="$INSTALL_DIR/openclaw.mjs"

# --turbofan vai no exec node, NAO em NODE_OPTIONS
cat > "$HOME/.local/bin/openclaw" << WRAPPER
#!/bin/bash
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
export NODE_OPTIONS="--max-old-space-size=${NODE_HEAP_MB} ${SEMI_SPACE}"
export UV_THREADPOOL_SIZE=${CPU_TOTAL}
exec node ${TURBOFAN} "${W_PATH}" "\$@"
WRAPPER
chmod +x "$HOME/.local/bin/openclaw"
ok "Wrapper criado em ~/.local/bin/openclaw"

# ── 10. .zshrc ────────────────────────────────────────────────
info "Atualizando ~/.zshrc..."
grep -q '\.local/bin' "$HOME/.zshrc" 2>/dev/null \
  || printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshrc"
grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null || {
  printf '\nexport NVM_DIR="$HOME/.nvm"\n' >> "$HOME/.zshrc"
  printf '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' >> "$HOME/.zshrc"
}
ok ".zshrc atualizado"

# ── 11. Teste final ───────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
echo ""
echo -e "${BLD}─────────────────────────────────────────${RST}"
echo -e "${GRN}${BLD}  OpenClaw instalado com sucesso${RST}"
echo -e "${BLD}─────────────────────────────────────────${RST}"
echo -e "  Chip:    Apple ${CHIP_GEN}${CHIP_VARIANT}"
echo -e "  Node.js: $(node --version)"
echo -e "  Heap:    $(( NODE_HEAP_MB/1024 )) GB de ${RAM_GB} GB"
echo ""
echo -e "${YLW}${BLD}  PROXIMO PASSO OBRIGATORIO:${RST}"
echo -e "  ${CYN}source ~/.zshrc${RST}"
echo -e "  ${CYN}openclaw onboard${RST}"
echo ""
