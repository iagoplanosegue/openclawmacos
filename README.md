# ⬡ OpenClaw — macOS Apple Silicon

[![Versão](https://img.shields.io/badge/versão-1.1.0-00ff88?style=flat-square&labelColor=0d1117)](https://github.com/iagoplanosegue/openclawmacos)
[![Chips](https://img.shields.io/badge/chips-M1%20%7C%20M2%20%7C%20M3%20%7C%20M4-00d4ff?style=flat-square&labelColor=0d1117)](https://github.com/iagoplanosegue/openclawmacos)
[![Node.js](https://img.shields.io/badge/Node.js-22-339933?style=flat-square&logo=node.js&logoColor=white&labelColor=0d1117)](https://nodejs.org)
[![Licença](https://img.shields.io/badge/licença-MIT-ff6b35?style=flat-square&labelColor=0d1117)](./LICENSE)
[![macOS](https://img.shields.io/badge/macOS-Ventura%2B-white?style=flat-square&logo=apple&logoColor=white&labelColor=0d1117)](https://www.apple.com/macos)

> Script de instalação otimizado para OpenClaw em Apple Silicon.  
> Detecta automaticamente seu chip (M1/M2/M3/M4) e ajusta heap, threads e paralelismo para máxima performance.

---
## 📋 Pré-requisitos

Antes de rodar o script, execute os três comandos abaixo em ordem:

**1. Xcode Command Line Tools**
```bash
xcode-select --install
```
> Abrirá uma janela gráfica — clique em **Instalar** e aguarde ~5 minutos.

**2. Homebrew**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**3. Recarregar o terminal**
```bash
source ~/.zshrc
```

## ⚡ Instalação rápida

```bash
curl -fsSL https://raw.githubusercontent.com/iagoplanosegue/openclawmacos/main/install.sh | bash
```

Depois de concluir:

```bash
source ~/.zshrc
openclaw onboard
```

---

## 🖥️ Chips suportados

| Chip | Variantes | Heap (16 GB) | Heap (8 GB) | Flags extras |
|------|-----------|:------------:|:-----------:|--------------|
| Apple M4 | base · Pro · Max · Ultra | 12 GB | 5 GB | `--turbofan --max-semi-space-size=256` |
| Apple M3 | base · Pro · Max · Ultra | 12 GB | 5 GB | `--turbofan --max-semi-space-size=192` |
| Apple M2 | base · Pro · Max · Ultra | 12 GB | 5 GB | `--turbofan --max-semi-space-size=128` |
| Apple M1 | base · Pro · Max · Ultra | 12 GB | 5 GB | `--max-semi-space-size=64` |

> O script detecta chip e RAM automaticamente — nenhuma configuração manual necessária.

---

**Verificação rápida antes de continuar:**
```bash
xcode-select --version  # xcode-select version 2409 (ou similar)
brew --version          # Homebrew 4.x.x
git --version           # git version 2.x.x
```

---

## 🔍 O que o script faz

```
1. Detecta seu chip Apple Silicon (M1/M2/M3/M4) e variante (Pro/Max/Ultra)
2. Calcula heap Node.js ideal baseado na RAM disponível
3. Instala nvm + Node.js 22 (se necessário)
4. Instala pnpm (mais rápido e eficiente que npm)
5. Clona o repositório OpenClaw em ~/.openclaw/install
6. Compila com otimizações específicas do chip detectado
7. Cria wrapper global em ~/.local/bin/openclaw com NODE_OPTIONS permanente
8. Atualiza ~/.zshrc com PATH e NVM_DIR
```

---

## 📊 Script padrão vs script otimizado

| Configuração | Script padrão | Script otimizado | Ganho |
|---|---|---|---|
| Heap Node.js | ~1.5 GB | até 56 GB | automático por chip |
| Thread pool | 4 threads | até 24 threads | automático por cores |
| Paralelismo pnpm | padrão | 80% dos p-cores | ~2× mais rápido |
| Detecção de chip | nenhuma | M1 / M2 / M3 / M4 | flags por geração |
| Comando global | symlink simples | wrapper otimizado | sempre otimizado |
| Diretório de install | /opt (SIP restrito) | ~/.openclaw | sem conflito com SIP |

---

## 🧠 Perfis de memória por configuração

```
M4 / M3 / M2 — 16 GB RAM
├── Node.js heap  →  12 GB  (75%)
└── macOS reserva →   4 GB  (25%)

M4 / M3 / M2 — 8 GB RAM
├── Node.js heap  →   5 GB  (62.5%)
└── macOS reserva →   3 GB  (37.5%)

M4 Max / M3 Max — 32 GB RAM
├── Node.js heap  →  26 GB  (81.25%)
└── macOS reserva →   6 GB  (18.75%)
```

> O macOS gerencia memória dinamicamente — o heap é um teto, não uma reserva fixa.  
> O sistema realoca conforme necessário sem comprometer a estabilidade.

---

## ❓ FAQ

**O script funciona em Intel Mac?**  
Não. O script foi projetado exclusivamente para Apple Silicon (arm64). Macs Intel têm arquitetura diferente e não se beneficiariam das otimizações.

**Posso rodar em Mac com 8 GB de RAM?**  
Sim. O script detecta 8 GB e reserva 3 GB para o macOS, alocando 5 GB para o Node.js.

**O que acontece se já tiver Node.js instalado?**  
O script verifica se já existe Node 22+ antes de instalar. Se já estiver presente, pula essa etapa.

**Como atualizar o OpenClaw depois?**  
Rode o script novamente. Ele limpa a instalação anterior em `~/.openclaw/install` e faz uma instalação limpa com a versão mais recente.

**O script modifica meu sistema fora do diretório home?**  
Não. Tudo é instalado em `~/.openclaw`, `~/.nvm` e `~/.local/bin` — dentro do seu diretório home, sem precisar de `sudo`.

**Por que `~/.local/bin` em vez de `/usr/local/bin`?**  
`/usr/local/bin` pode ser protegido pelo SIP (System Integrity Protection) do macOS. `~/.local/bin` é um padrão Unix sem restrições, e o script já adiciona ao PATH automaticamente.

---

## 🐛 Reportar problemas

Encontrou um bug ou comportamento inesperado?  
Abra uma [issue](https://github.com/iagoplanosegue/openclawmacos/issues) com:

- Saída completa do terminal
- Resultado de `sysctl -n machdep.cpu.brand_string`
- Resultado de `sysctl -n hw.memsize`
- Versão do macOS (`sw_vers`)

---

## 📝 Changelog

### [1.1.0] — 2026-03-08
- Suporte completo a M1, M2, M3 e M4
- Detecção automática de variante (base / Pro / Max / Ultra)
- Perfis de heap ajustados por geração de chip
- Flags `--turbofan` e `--max-semi-space-size` por chip
- `printf` no lugar de `echo` no `.zshrc` (sem erros de history expansion)
- Wrapper global com `UV_THREADPOOL_SIZE` automático

### [1.0.0] — 2026-03-01
- Versão inicial para Mac Mini M4 16 GB
- Detecção de RAM e cálculo de heap
- Instalação de nvm, Node.js 22 e pnpm
- Wrapper global em `~/.local/bin`

---

## 📄 Licença

MIT © [Iago PlanoSegue](https://github.com/iagoplanosegue)

---

<div align="center">
  <sub>Guia completo de instalação em <a href="https://planosegue.com/mac">planosegue.com</a></sub>
</div>
