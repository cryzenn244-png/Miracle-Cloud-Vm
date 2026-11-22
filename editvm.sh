#!/usr/bin/env bash
set -Eeuo pipefail

# Miracle Cloud VM Manager v7 — safe configuration editor.
# This tool edits VM .conf files only. It never rebuilds, resizes, replaces or deletes disks.
# Use VM_DIR=/path/to/vms if your manager stores VMs somewhere else.

RESET='\033[0m'; BOLD='\033[1m'; PURPLE='\033[1;35m'; GOLD='\033[1;33m'; CYAN='\033[1;36m'; GREEN='\033[1;32m'; RED='\033[1;31m'; GRAY='\033[1;90m'
info(){ printf "${CYAN}[MIRACLE • INFO]${RESET} %s\n" "$*"; }
ok(){ printf "${GREEN}[MIRACLE • OK]${RESET} %s\n" "$*"; }
warn(){ printf "${GOLD}[MIRACLE • WARN]${RESET} %s\n" "$*"; }
err(){ printf "${RED}[MIRACLE • ERROR]${RESET} %s\n" "$*" >&2; }
die(){ err "$*"; exit 1; }

VM_DIR="${VM_DIR:-${HOME}/vms}"
[[ -d "$VM_DIR" ]] || die "VM directory not found: $VM_DIR. Set VM_DIR=/path/to/vms."
mapfile -t VM_LIST < <(find "$VM_DIR" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' | sed 's/\.conf$//' | sort)
((${#VM_LIST[@]} > 0)) || die "No VM .conf files found in $VM_DIR"

clear 2>/dev/null || true
printf "${PURPLE}╔══════════════════════════════════════════════════════════════════════╗${RESET}\n"
printf "${PURPLE}║${GOLD}                 ✦ MIRACLE CLOUD VM • EDITOR v7 ✦                    ${PURPLE}║${RESET}\n"
printf "${PURPLE}║${GRAY}             Safe config changes • No disk rebuilds                    ${PURPLE}║${RESET}\n"
printf "${PURPLE}╚══════════════════════════════════════════════════════════════════════╝${RESET}\n\n"
printf 'VM directory: %s\n\n' "$VM_DIR"
for i in "${!VM_LIST[@]}"; do printf "  ${GOLD}%2d)${RESET} %s\n" "$((i+1))" "${VM_LIST[$i]}"; done
printf '\n'
read -r -p 'Select VM number (0 to cancel): ' choice
[[ "$choice" == 0 ]] && exit 0
[[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#VM_LIST[@]})) || die 'Invalid VM selection.'

SELECTED_NAME="${VM_LIST[$((choice-1))]}"
CONF="$VM_DIR/$SELECTED_NAME.conf"
[[ -f "$CONF" ]] || die "Config not found: $CONF"
# Configs are shell files created by manager.sh. Only source configs you trust.
# shellcheck disable=SC1090
source "$CONF"

VM_NAME="${VM_NAME:-$SELECTED_NAME}"
OS_TYPE="${OS_TYPE:-ubuntu}"; CODENAME="${CODENAME:-noble}"; IMG_URL="${IMG_URL:-}"
HOSTNAME="${HOSTNAME:-$VM_NAME}"; USERNAME="${USERNAME:-ubuntu}"; PASSWORD="${PASSWORD:-}"
DISK_SIZE="${DISK_SIZE:-20G}"; MEMORY="${MEMORY:-2048}"; CPUS="${CPUS:-2}"; SSH_PORT="${SSH_PORT:-2222}"
GUI_MODE="${GUI_MODE:-false}"; PORT_FORWARDS="${PORT_FORWARDS:-}"
CPU_LABEL="${CPU_LABEL:-Ryzen EPYC Genoa (Zen 4 Class)}"; CPU_MODEL="${CPU_MODEL:-EPYC-Genoa-v1}"; CPU_FLAGS="${CPU_FLAGS:-+ibpb,+virt-ssbd}"
IMG_FILE="${IMG_FILE:-$VM_DIR/$VM_NAME.img}"; SEED_FILE="${SEED_FILE:-$VM_DIR/$VM_NAME-seed.iso}"
CREATED="${CREATED:-$(date '+%Y-%m-%d %H:%M:%S')}"

valid_name(){ [[ "$1" =~ ^[a-zA-Z0-9_-]{1,63}$ ]]; }
valid_user(){ [[ "$1" =~ ^[a-z_][a-z0-9_-]*$ ]]; }
valid_size(){ [[ "$1" =~ ^[1-9][0-9]*[GgMm]$ ]]; }
valid_num(){ [[ "$1" =~ ^[1-9][0-9]*$ ]]; }
valid_port(){ [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 23 && 10#$1 <= 65535)); }

choose_cpu(){
  local -a labels=(
    "Ryzen EPYC Genoa (Zen 4 Class)"
    "Ryzen EPYC Milan (Zen 3 Class)"
    "Ryzen EPYC Rome (Zen 2 Class)"
    "Ryzen EPYC Classic (Zen 1 Class)"
    "AMD EPYC generic"
    "Intel Xeon Skylake Server"
    "Intel Xeon Cascade Lake Server"
    "Intel Broadwell"
    "Intel Haswell"
    "Generic x86-64 (portable)"
    "Host passthrough (KVM only)"
  )
  local -a models=("EPYC-Genoa-v1" "EPYC-Milan-v2" "EPYC-Rome-v4" "EPYC-v4" "EPYC" "Skylake-Server" "Cascadelake-Server" "Broadwell" "Haswell" "qemu64" "host")
  local -a flags=("+ibpb,+virt-ssbd" "+ibpb,+virt-ssbd" "+ibpb,+virt-ssbd" "+ibpb,+virt-ssbd" "+ibpb,+virt-ssbd" "" "" "" "" "" "+virt-ssbd")
  echo
  info "CPU profiles (availability depends on installed QEMU and host acceleration):"
  local i
  for i in "${!labels[@]}"; do printf ' %2d) %s [%s]\n' "$((i+1))" "${labels[$i]}" "${models[$i]}"; done
  read -r -p "Choose profile (Enter keeps $CPU_LABEL): " c
  [[ -z "$c" ]] && return 0
  [[ "$c" =~ ^[0-9]+$ ]] && ((c>=1 && c<=${#labels[@]})) || { warn "Invalid profile; unchanged."; return 0; }
  CPU_LABEL="${labels[$((c-1))]}"; CPU_MODEL="${models[$((c-1))]}"; CPU_FLAGS="${flags[$((c-1))]}"
  if [[ "$CPU_MODEL" == host ]] && [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    warn "Host passthrough usually requires accessible /dev/kvm. It is saved as requested but may not start on this host."
  fi
  ok "Selected $CPU_LABEL ($CPU_MODEL)"
}

show_config(){
  echo
  printf "${CYAN}Current configuration${RESET}\n"
  printf 'VM: %s | OS: %s %s\nCPU: %s (%s)\nRAM: %s MB | vCPU: %s | Disk: %s\nHostname: %s | User: %s | SSH host port: %s\nGUI: %s | Port forwards: %s\n' \
    "$VM_NAME" "$OS_TYPE" "$CODENAME" "$CPU_LABEL" "$CPU_MODEL" "$MEMORY" "$CPUS" "$DISK_SIZE" "$HOSTNAME" "$USERNAME" "$SSH_PORT" "$GUI_MODE" "${PORT_FORWARDS:-none}"
  printf 'Password: [hidden]\n\n'
}

save_config(){
  local stamp backup tmp
  stamp="$(date '+%Y%m%d-%H%M%S')"
  backup="$CONF.pre-v7-edit-$stamp"
  tmp="$(mktemp "$VM_DIR/.${VM_NAME}.conf.XXXXXX")"
