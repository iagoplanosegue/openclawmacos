cat > install.sh << 'ENDOFSCRIPT'
#!/bin/bash
# ================================================================
#  INSTALADOR OPENCLAW - macOS Apple Silicon Universal
#  Detecta automaticamente: M1 / M2 / M3 / M4
# ================================================================
set -e

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

case "$CHIP_GEN" in
  M4) NODE_EXTRA="--turbofan --max-semi-space-size=256" ;;
  M3) NODE_EXTRA="--turbofan --max-semi-space-size=192" ;;
  M2) NODE_EXTRA="--turbofan --max-semi-space-size=128" ;;
  M1) NODE_EXTRA="--max-semi-space-size=64"             ;;
esac

echo "Chip: Apple ${CHIP_GEN}${CHIP_VARIANT} | RAM: ${RAM_GB}GB | Heap: $(( NODE_HEAP_MB/1024 ))GB"

export NVM_DIR="$HOME/.nvm"
[ -d "$NVM_DIR" ] || curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
command -v node >/dev/null 2>&1 || { nvm install 22; nvm use 22; nvm alias default 22; }

command -v pnpm >/dev/null 2>&1 || npm install -g pnpm
command -v git  >/dev/null 2>&1 || { echo "Git nao encontrado: xcode-select --install"; exit 1; }

[ -d "$HOME/.openclaw/install" ] && rm -rf "$HOME/.openclaw/install"
mkdir -p "$HOME/.openclaw/install" && cd "$HOME/.openclaw/install"
git clone --depth 1 https://github.com/openclaw/openclaw.git && cd openclaw
PNPM_CONCURRENCY=$PNPM_WORKERS pnpm install
NODE_OPTIONS="--max-old-space-size=${NODE_HEAP_MB} ${NODE_EXTRA}" pnpm run build

mkdir -p "$HOME/.local/bin"
W_PATH="$HOME/.openclaw/install/openclaw/openclaw.mjs"
cat > "$HOME/.local/bin/openclaw" << WRAPPER
#!/bin/bash
export NODE_OPTIONS="--max-old-space-size=${NODE_HEAP_MB} ${NODE_EXTRA}"
export UV_THREADPOOL_SIZE=${CPU_TOTAL}
exec node "${W_PATH}" "\$@"
WRAPPER
chmod +x "$HOME/.local/bin/openclaw"

grep -q ".local/bin" "$HOME/.zshrc" 2>/dev/null || printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshrc"
grep -q "NVM_DIR"    "$HOME/.zshrc" 2>/dev/null || {
  printf '\nexport NVM_DIR="$HOME/.nvm"\n' >> "$HOME/.zshrc"
  printf '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' >> "$HOME/.zshrc"
}

echo "Concluido. Execute: source ~/.zshrc && openclaw onboard"
ENDOFSCRIPT
chmod +x install.sh && ./install.sh
