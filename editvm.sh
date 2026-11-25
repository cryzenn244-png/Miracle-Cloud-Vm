#!/usr/bin/env bash
set -Eeuo pipefail

# Miracle Cloud VM Manager v8 — safe configuration editor.
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
printf "${PURPLE}║${GOLD}                 ✦ MIRACLE CLOUD VM • EDITOR v8 ✦                    ${PURPLE}║${RESET}\n"
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
MIRACLE_PLUS="${MIRACLE_PLUS:-false}"; AUTOSTART="${AUTOSTART:-false}"; VNC_PASSWORD="${VNC_PASSWORD:-}"

valid_name(){ [[ "$1" =~ ^[a-zA-Z0-9_-]{1,63}$ ]]; }
valid_user(){ [[ "$1" =~ ^[a-z_][a-z0-9_-]*$ ]]; }
valid_size(){ [[ "$1" =~ ^[1-9][0-9]*[GgMm]$ ]]; }
valid_num(){ [[ "$1" =~ ^[1-9][0-9]*$ ]]; }
valid_port(){ [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 23 && 10#$1 <= 65535)); }

choose_cpu(){
  local -a profiles=(
    'AMD Ryzen 9 9950X (Zen 5 class; approximate)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD Ryzen 9 7950X|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD Ryzen 9 7950X3D (3D V-Cache not emulated)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD Ryzen 7 9800X3D (3D V-Cache not emulated)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD Ryzen 7 9700X (Zen 5 class; approximate)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD Ryzen 9 7900X|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD Ryzen 7 7700X|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD Ryzen 9 5950X|EPYC-Milan-v2|+ibpb,+virt-ssbd'
    'AMD Ryzen 9 5900X|EPYC-Milan-v2|+ibpb,+virt-ssbd'
    'AMD Ryzen 7 5800X3D (3D V-Cache not emulated)|EPYC-Milan-v2|+ibpb,+virt-ssbd'
    'AMD Ryzen 7 5800X|EPYC-Milan-v2|+ibpb,+virt-ssbd'
    'Intel Core Ultra 9 285K (approximate server model)|SapphireRapids|'
    'Intel Core Ultra 7 265K (approximate server model)|SapphireRapids|'
    'Intel Core i9-14900K (hybrid layout not emulated)|Cascadelake-Server|'
    'Intel Core i9-13900K (hybrid layout not emulated)|Cascadelake-Server|'
    'Intel Core i7-14700K (hybrid layout not emulated)|Cascadelake-Server|'
    'Intel Core i7-13700K (hybrid layout not emulated)|Cascadelake-Server|'
    'Intel Core i9-12900K (hybrid layout not emulated)|Skylake-Server|'
    'Intel Core i7-12700K (hybrid layout not emulated)|Skylake-Server|'
    'AMD EPYC 4584PX (closest QEMU EPYC model)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD EPYC 4565P (closest QEMU EPYC model)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD EPYC 9354P|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD EPYC 9334|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD EPYC 9124|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
    'AMD EPYC 7763|EPYC-Milan-v2|+ibpb,+virt-ssbd'
    'AMD EPYC 7543P|EPYC-Milan-v2|+ibpb,+virt-ssbd'
    'Intel Xeon E-2388G (approximate)|Cascadelake-Server|'
    'Intel Xeon E-2488 (approximate)|Cascadelake-Server|'
    'Intel Xeon Gold 6442Y|SapphireRapids|'
    'Intel Xeon Gold 5317|Icelake-Server|'
    'Generic x86-64 (portable)|qemu64|'
    'Host passthrough (KVM only)|host|+virt-ssbd'
  )
  echo
  info "CPU choices map retail names to QEMU CPU models; they do not emulate retail-specific cache, hybrid cores, or exact silicon."
  local i label model flags
  for i in "${!profiles[@]}"; do IFS='|' read -r label model flags <<< "${profiles[$i]}"; printf ' %2d) %s [%s]
' "$((i+1))" "$label" "$model"; done
  read -r -p "Choose profile (Enter keeps $CPU_LABEL): " c
  [[ -z "$c" ]] && return 0
  [[ "$c" =~ ^[0-9]+$ ]] && ((c>=1 && c<=${#profiles[@]})) || { warn "Invalid profile; unchanged."; return 0; }
  IFS='|' read -r CPU_LABEL CPU_MODEL CPU_FLAGS <<< "${profiles[$((c-1))]}"
  if [[ "$CPU_MODEL" == host ]] && [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then warn "Host passthrough requires accessible /dev/kvm; this setting may not start on this host."; fi
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
  backup="$CONF.pre-v8-edit-$stamp"
  tmp="$(mktemp "$VM_DIR/.${VM_NAME}.conf.XXXXXX")"
  cp -a -- "$CONF" "$backup" || { rm -f "$tmp"; die "Could not back up current config."; }
  # Bash %q safely quotes values so special characters do not corrupt shell syntax.
  {
    printf 'VM_NAME=%q\n' "$VM_NAME"
    printf 'OS_TYPE=%q\n' "$OS_TYPE"
    printf 'CODENAME=%q\n' "$CODENAME"
    printf 'IMG_URL=%q\n' "$IMG_URL"
    printf 'HOSTNAME=%q\n' "$HOSTNAME"
    printf 'USERNAME=%q\n' "$USERNAME"
    printf 'PASSWORD=%q\n' "$PASSWORD"
    printf 'DISK_SIZE=%q\n' "$DISK_SIZE"
    printf 'MEMORY=%q\n' "$MEMORY"
    printf 'CPUS=%q\n' "$CPUS"
    printf 'SSH_PORT=%q\n' "$SSH_PORT"
    printf 'GUI_MODE=%q\n' "$GUI_MODE"
    printf 'PORT_FORWARDS=%q\n' "$PORT_FORWARDS"
    printf 'CPU_LABEL=%q\n' "$CPU_LABEL"
    printf 'CPU_MODEL=%q\n' "$CPU_MODEL"
    printf 'CPU_FLAGS=%q\n' "$CPU_FLAGS"
    printf 'IMG_FILE=%q\n' "$IMG_FILE"
    printf 'SEED_FILE=%q\n' "$SEED_FILE"
    printf 'CREATED=%q\n' "$CREATED"
    printf 'MIRACLE_PLUS=%q\n' "$MIRACLE_PLUS"
    printf 'AUTOSTART=%q\n' "$AUTOSTART"
    printf 'VNC_PASSWORD=%q\n' "$VNC_PASSWORD"
  } > "$tmp"
  chmod 600 "$tmp"
  mv -f -- "$tmp" "$CONF"
  ok "Configuration saved. Backup: $backup"
  warn "No disk or seed ISO was changed. Resource/CPU/port changes apply the next time the VM starts."
}

while true; do
  show_config
  cat <<'EOF'
  1) Hostname
  2) Username (config only; does not change the existing guest account)
  3) Login password (config only; does not change the existing guest password)
  4) SSH host port
  5) GUI mode
  6) Port forwards
  7) Memory (MB)
  8) vCPU count
  9) Disk size label (metadata only; does NOT resize the disk)
 10) CPU profile
 11) Show Termius connection fields
 12) Show IPv4/networking guidance
  0) Save & exit
EOF
  read -r -p 'Select option: ' action
  case "$action" in
    1)
      read -r -p "Hostname [$HOSTNAME]: " v
      if [[ -n "$v" ]]; then valid_name "$v" || { warn "Invalid hostname."; continue; }; HOSTNAME="$v"; fi ;;
    2)
      read -r -p "Username [$USERNAME]: " v
      if [[ -n "$v" ]]; then valid_user "$v" || { warn "Invalid username."; continue; }; USERNAME="$v"; fi ;;
    3)
      read -r -s -p 'New config password (blank keeps current): ' v; echo
      [[ -n "$v" ]] && PASSWORD="$v"
      warn "This only updates manager config. It does not change the password inside an already-installed guest." ;;
    4)
      read -r -p "SSH host port [$SSH_PORT]: " v
      if [[ -n "$v" ]]; then valid_port "$v" || { warn "Port must be 23-65535."; continue; }; SSH_PORT="$v"; fi ;;
    5)
      read -r -p "Enable GUI mode? (y/n) [$GUI_MODE]: " v
      case "${v,,}" in y|yes) GUI_MODE=true;; n|no) GUI_MODE=false;; '') ;; *) warn "Enter y or n."; continue;; esac ;;
    6)
      read -r -p "Port forwards host:guest, comma-separated [${PORT_FORWARDS:-none}]: " v
      if [[ -n "$v" ]]; then
        IFS=',' read -ra pairs <<< "$v"
        valid=true
        for pair in "${pairs[@]}"; do
          if ! [[ "$pair" =~ ^[0-9]+:[0-9]+$ ]]; then valid=false; break; fi
          a=${pair%%:*}; b=${pair##*:}
          if ((a<1 || a>65535 || b<1 || b>65535)); then valid=false; break; fi
        done
        [[ "$valid" == true ]] || { warn "Use host:guest pairs such as 25565:25565."; continue; }
        PORT_FORWARDS="$v"
      fi ;;
    7)
      read -r -p "RAM MB [$MEMORY]: " v
      if [[ -n "$v" ]]; then valid_num "$v" || { warn "Enter a positive integer."; continue; }; MEMORY="$v"; fi ;;
    8)
      read -r -p "vCPU cores [$CPUS]: " v
      if [[ -n "$v" ]]; then valid_num "$v" || { warn "Enter a positive integer."; continue; }; CPUS="$v"; fi ;;
    9)
      read -r -p "Disk size label [$DISK_SIZE]: " v
      if [[ -n "$v" ]]; then valid_size "$v" || { warn "Use a size like 20G or 512M."; continue; }; DISK_SIZE="$v"; warn "This edits metadata only. Use a dedicated disk resize workflow to resize a disk safely."; fi ;;
    10) choose_cpu ;;
    11)
      echo
      echo "Termius fields (the host address depends on your provider):"
      echo "  Address: detect host public IPv4 from the manager's networking report"
      echo "  Port: $SSH_PORT"
      echo "  Username: $USERNAME"
      echo "  Password: your guest password (not displayed)"
      echo "  Local test: ssh -p $SSH_PORT $USERNAME@127.0.0.1"
      echo "QEMU user-mode NAT does not give the guest its own public IPv4." ;;
    12)
      echo
      if command -v ip >/dev/null 2>&1; then ip -4 -brief address show || true; fi
      echo "QEMU default is user-mode NAT; guest commonly uses a private 10.0.2.x address."
      echo "Static public IPv4 requires provider support and correctly configured bridge/TAP routing."
      echo "No host or guest network settings were changed." ;;
    0) save_config; exit 0 ;;
    *) warn "Invalid option." ;;
  esac
done
