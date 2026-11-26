#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║ Miracle Cloud · Railway Edition                                     ║
# ║ Standalone terminal manager: works via bash <(curl -fsSL URL)         ║
# ║ Uses Incus when available; otherwise offers a PRoot userspace sandbox║
# ╚══════════════════════════════════════════════════════════════════════╝
set -Eeuo pipefail
umask 077

VERSION="2.0.0-railway"
APP="MIRACLE CLOUD / RAILWAY EDITION"
DATA_HOME="${MIRACLE_HOME:-${HOME:-/tmp}/.local/share/miracle-cloud-railway}"
BIN_DIR="$DATA_HOME/bin"
SANDBOX_DIR="$DATA_HOME/sandboxes"
CACHE_DIR="$DATA_HOME/cache"

# Premium terminal palette; automatically falls back to plain text when not a TTY.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  RED=$'\033[38;5;203m'; PINK=$'\033[38;5;213m'; PURPLE=$'\033[38;5;141m'
  CYAN=$'\033[38;5;117m'; GREEN=$'\033[38;5;120m'; YELLOW=$'\033[38;5;221m'
  GRAY=$'\033[38;5;245m'; WHITE=$'\033[97m'
else
  RESET=''; BOLD=''; DIM=''; RED=''; PINK=''; PURPLE=''; CYAN=''; GREEN=''; YELLOW=''; GRAY=''; WHITE=''
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s  %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s  %s\n' "$YELLOW" "$RESET" "$*" >&2; }
err()  { printf '%s✕%s  %s\n' "$RED" "$RESET" "$*" >&2; }
info() { printf '%s›%s  %s\n' "$CYAN" "$RESET" "$*"; }
die()  { err "$*"; exit 1; }
hr()   { printf '%s────────────────────────────────────────────────────────────────────────%s\n' "$DIM" "$RESET"; }

banner() {
  printf '%s\n' "${PURPLE}╭──────────────────────────────────────────────────────────────────────╮${RESET}"
  printf '%s\n' "${PURPLE}│${RESET}  ${PINK}✦${RESET} ${BOLD}${WHITE}MIRACLE CLOUD${RESET}  ${GRAY}·${RESET} ${CYAN}RAILWAY EDITION${RESET}                                  ${PURPLE}│${RESET}"
  printf '%s\n' "${PURPLE}│${RESET}  ${GRAY}Portable terminal manager · v${VERSION}${RESET}                              ${PURPLE}│${RESET}"
  printf '%s\n' "${PURPLE}╰──────────────────────────────────────────────────────────────────────╯${RESET}"
}

startup_animation() {
  [[ -t 1 && -z "${MIRACLE_NO_ANIMATION:-}" ]] || return 0
  local frames=("Checking runtime capabilities" "Preparing instance workspace" "Loading Miracle control plane")
  local i
  for i in 0 1 2; do
    printf '\r%s◇%s %-36s %s[%s/3]%s' "$PURPLE" "$RESET" "${frames[$i]}" "$GRAY" "$((i+1))" "$RESET"
    sleep 0.18
    printf ' %s✓%s' "$GREEN" "$RESET"
  done
  printf '\n\n'
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
prepare_dirs() {
  mkdir -p "$BIN_DIR" "$SANDBOX_DIR" "$CACHE_DIR" 2>/dev/null || die "Cannot create data directory: $DATA_HOME. Set MIRACLE_HOME to a writable path."
  [[ -w "$DATA_HOME" && -w "$SANDBOX_DIR" ]] || die "Data directory is not writable: $DATA_HOME"
}
valid_name() { [[ "${1:-}" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,30}$ ]]; }
require_name() { valid_name "${1:-}" || die "Invalid name. Use 1–31 letters/digits/_/-, starting with a letter."; }

arch_lxc() {
  case "$(uname -m 2>/dev/null || echo unknown)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) echo unsupported ;;
  esac
}
arch_proot() {
  case "$(uname -m 2>/dev/null || echo unknown)" in
    x86_64|amd64) echo x86_64 ;;
    aarch64|arm64) echo aarch64 ;;
    *) echo unsupported ;;
  esac
}

incus_ready() {
  command -v incus >/dev/null 2>&1 && incus info >/dev/null 2>&1
}

is_sandbox() { [[ -d "$SANDBOX_DIR/$1/rootfs" ]]; }

check_report() {
  local arch caps=0 cgroup_state="not detected" ptrace_state="unknown"
  arch="$(uname -m 2>/dev/null || echo unknown)"
  banner
  say "${BOLD}Runtime diagnostics${RESET}"
  hr
  if [[ -n "${RAILWAY_ENVIRONMENT_NAME:-}" ]]; then
    printf 'Platform       : Railway (%s)\n' "$RAILWAY_ENVIRONMENT_NAME"
  elif [[ -n "${RAILWAY_SERVICE_ID:-}" ]]; then
    printf 'Platform       : Railway service\n'
  else
    printf 'Platform       : not identified as Railway (script still runs)\n'
  fi
  printf 'Architecture   : %s\n' "$arch"
