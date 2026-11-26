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
  printf 'User / UID     : %s / %s\n' "$(id -un 2>/dev/null || echo unknown)" "$(id -u 2>/dev/null || echo '?')"
  printf 'Writable home  : %s\n' "$([[ -w "${HOME:-/tmp}" ]] && echo yes || echo no)"
  printf 'cgroup view    : %s\n' "$([[ -r /sys/fs/cgroup/cgroup.controllers ]] && echo visible || echo limited/not-v2)"
  if [[ -w /sys/fs/cgroup ]]; then cgroup_state="writable"; else cgroup_state="read-only or inaccessible"; fi
  printf 'cgroup control : %s\n' "$cgroup_state"
  printf 'Docker CLI     : %s\n' "$(command -v docker 2>/dev/null || echo unavailable)"
  if [[ -S /var/run/docker.sock ]]; then printf 'Docker socket  : present (access still needs verification)\n'; else printf 'Docker socket  : unavailable\n'; fi
  printf 'LXC CLI        : %s\n' "$(command -v lxc 2>/dev/null || echo unavailable)"
  printf 'Incus CLI      : %s\n' "$(command -v incus 2>/dev/null || echo unavailable)"
  printf 'QEMU CLI       : %s\n' "$(command -v qemu-system-x86_64 2>/dev/null || echo unavailable)"
  if [[ -r /proc/1/comm ]]; then printf 'PID 1           : %s\n' "$(cat /proc/1/comm 2>/dev/null || echo unknown)"; fi
  printf 'systemd PID 1   : %s\n' "$( [[ "$(cat /proc/1/comm 2>/dev/null || true)" == systemd ]] && echo yes || echo no )"
  printf 'KVM device      : %s\n' "$( [[ -r /dev/kvm && -w /dev/kvm ]] && echo accessible || echo unavailable )"
  printf 'unshare command : %s\n' "$(command -v unshare 2>/dev/null || echo unavailable)"
  if command -v unshare >/dev/null 2>&1 && unshare -Ur true >/dev/null 2>&1; then caps=1; fi
  printf 'user namespace  : %s\n' "$([[ $caps -eq 1 ]] && echo available || echo blocked/unsupported)"
  printf 'PRoot binary    : %s\n' "$( [[ -x "$BIN_DIR/proot" ]] && echo installed || command -v proot 2>/dev/null || echo not-installed )"
  hr
  if incus_ready; then
    ok "Incus API is reachable. Full system containers may be available; host policy still controls nesting."
  else
    warn "No reachable local Incus daemon detected. A real system container cannot be created by this script here."
    info "The PRoot fallback is a Linux userspace sandbox, not a VM; it cannot provide a real systemd PID 1 or Docker daemon."
  fi
  say "Data path: $DATA_HOME"
  say "For persistence across redeploys, set MIRACLE_HOME to a path backed by a Railway Volume."
}

install_proot() {
  if [[ -x "$BIN_DIR/proot" ]]; then
    "$BIN_DIR/proot" --version >/dev/null 2>&1 && return 0
    warn "Cached PRoot binary failed its version check; replacing it."
    rm -f -- "$BIN_DIR/proot"
  fi
  local arch url tmp
  arch="$(arch_proot)"
  [[ "$arch" != unsupported ]] || die "Unsupported CPU architecture for the official static PRoot download: $(uname -m)"
  require_cmd curl
  tmp="$CACHE_DIR/proot.download"
  url="https://github.com/selkies-project/proot-next/releases/latest/download/proot-${arch}"
  info "Downloading static PRoot for ${arch}…"
  curl --fail --location --silent --show-error --retry 2 --connect-timeout 10 --max-time 180 "$url" -o "$tmp" || die "Could not download PRoot. Check outbound HTTPS and try again."
  chmod 700 "$tmp"
  "$tmp" --version >/dev/null 2>&1 || { rm -f -- "$tmp"; die "Downloaded PRoot binary did not pass its version check."; }
  mv -f -- "$tmp" "$BIN_DIR/proot"
  chmod 700 "$BIN_DIR/proot"
  ok "PRoot installed in $BIN_DIR"
}

resolve_image() {
  # Return the official Linux Containers image-server path for supported releases.
  case "$1" in
    debian) printf '%s\n' 'debian/bookworm' ;;
    ubuntu) printf '%s\n' 'ubuntu/noble' ;;
    *) return 1 ;;
  esac
}

fetch_rootfs() {
  local distro="$1" dest="$2" arch base listing latest archive_url temp_archive temp_root
  arch="$(arch_lxc)"
  [[ "$arch" != unsupported ]] || die "Unsupported architecture for Linux Containers images: $(uname -m)"
  base="$(resolve_image "$distro")" || die "Supported fallback distributions: debian or ubuntu."
  base="https://images.linuxcontainers.org/images/${base}/${arch}/default/"
  info "Finding latest ${distro} rootfs image…"
  listing="$(curl --fail --location --silent --show-error --connect-timeout 10 --max-time 45 "$base")" || die "Cannot reach the Linux Containers image server."
  latest="$(printf '%s\n' "$listing" | grep -oE 'href="[0-9]{8}_[^"/]+/"' | sed -E 's/^href="([^"]+)"$/\1/' | sort | tail -n 1)"
  [[ -n "$latest" ]] || die "Could not discover a current rootfs archive under $base"
  archive_url="${base}${latest}rootfs.tar.xz"
  temp_archive="$CACHE_DIR/rootfs-${distro}.tar.xz"
  temp_root="$CACHE_DIR/rootfs-${distro}.tmp"
  rm -f -- "$temp_archive"
  rm -rf -- "$temp_root"
  mkdir -p "$temp_root"
  info "Downloading ${distro} rootfs. This is a one-time download for this instance…"
  curl --fail --location --silent --show-error --retry 2 --connect-timeout 10 --max-time 900 "$archive_url" -o "$temp_archive" || {
    rm -f -- "$temp_archive"; rm -rf -- "$temp_root"; die "Rootfs download failed: $archive_url";
  }
  [[ -s "$temp_archive" ]] || { rm -f -- "$temp_archive"; die "The rootfs archive is empty."; }
  info "Extracting root filesystem…"
  tar -xf "$temp_archive" -C "$temp_root" --no-same-owner || { rm -rf -- "$temp_root"; die "Could not extract the rootfs; ensure tar and xz support are available."; }
  [[ -x "$temp_root/bin/sh" || -x "$temp_root/usr/bin/sh" ]] || { rm -rf -- "$temp_root"; die "The downloaded archive does not look like a Linux root filesystem."; }
  mkdir -p "$(dirname "$dest")"
  mv -- "$temp_root" "$dest"
  rm -f -- "$temp_archive"
}

create_sandbox() {
  local name="${1:-}" distro="${2:-debian}" rootfs
  prepare_dirs
  [[ -n "$name" ]] || { [[ -t 0 ]] || die "Usage: $0 create NAME [debian|ubuntu]"; read -r -p "Sandbox name [miracle-debian]: " name; name="${name:-miracle-debian}"; }
  require_name "$name"
  case "$distro" in debian|ubuntu) ;; *) die "Fallback distro must be 'debian' or 'ubuntu'." ;; esac
  [[ ! -e "$SANDBOX_DIR/$name" ]] || die "An environment named '$name' already exists."
  install_proot
  rootfs="$SANDBOX_DIR/$name/rootfs"
  mkdir -p "$SANDBOX_DIR/$name"
  if ! fetch_rootfs "$distro" "$rootfs"; then rm -rf -- "$SANDBOX_DIR/$name"; return 1; fi
  printf '%s\n' "$distro" > "$SANDBOX_DIR/$name/distro"
  chmod 600 "$SANDBOX_DIR/$name/distro"
  ok "Linux userspace sandbox '$name' created."
  warn "This is PRoot userspace, NOT a virtual machine: systemd-as-PID-1 and Docker daemon are not supported here."
  warn "CPU/RAM/disk are not independently quota-limited; the sandbox shares the Railway service limits."
  info "Enter it with: bash <(curl -fsSL YOUR_RAW_GITHUB_URL) shell $name"
}

incus_create() {
  local name="$1" distro="$2" cpu="$3" ram="$4" disk="$5" image
  require_name "$name"
  case "$distro" in debian) image="images:debian/12" ;; ubuntu) image="images:ubuntu/24.04" ;; *) die "Distro must be debian or ubuntu." ;; esac
  [[ "$cpu" =~ ^[1-9][0-9]?$ ]] || die "CPU must be an integer from 1 to 64."
  [[ "$ram" =~ ^[1-9][0-9]*$ ]] && (( ram >= 256 && ram <= 1048576 )) || die "RAM must be 256–1048576 MiB."
  [[ "$disk" =~ ^[1-9][0-9]*$ ]] && (( disk >= 2 && disk <= 4096 )) || die "Disk must be 2–4096 GiB."
  if incus info "$name" >/dev/null 2>&1; then die "An Incus instance named '$name' already exists."; fi
  info "Creating system container ${name} via the detected Incus daemon…"
  incus launch "$image" "$name" \
    --config "limits.cpu=$cpu" \
    --config "limits.memory=${ram}MiB" \
    --config "security.nesting=true" \
    --config "security.syscalls.intercept.mknod=true" \
    --config "security.syscalls.intercept.setxattr=true" \
    --config "boot.autostart=true" || die "Incus failed to launch the container. Inspect the Incus daemon and image remote."
  if ! incus config device override "$name" root "size=${disk}GiB" >/dev/null 2>&1; then
    warn "Instance started, but the root disk quota was not applied. Check your Incus storage pool/profile."
  fi
  ok "System container '$name' started."
  info "Docker-in-container still depends on host kernel, cgroups, storage and Incus policy."
}

create_instance() {
  local name="${1:-}" distro="${2:-debian}" cpu="${3:-2}" ram="${4:-2048}" disk="${5:-10}"
  if incus_ready; then
    if [[ -z "$name" && -t 0 ]]; then read -r -p "Instance name [miracle-01]: " name; name="${name:-miracle-01}"; fi
    [[ -n "$name" ]] || die "Usage: $0 create NAME [debian|ubuntu] [cpu] [ram_mib] [disk_gib]"
    incus_create "$name" "$distro" "$cpu" "$ram" "$disk"
  else
    [[ -n "$name" ]] || { [[ -t 0 ]] || die "Usage: $0 create NAME [debian|ubuntu]. No local Incus daemon is available."; read -r -p "Sandbox name [miracle-debian]: " name; name="${name:-miracle-debian}"; }
    create_sandbox "$name" "$distro"
  fi
}

list_instances() {
  prepare_dirs
  banner
  if incus_ready; then
    say "${BOLD}Incus system containers${RESET}"
    incus list || warn "Could not list Incus instances."
  else
    say "${BOLD}PRoot Linux sandboxes (not VMs)${RESET}"
    local found=0 d name distro
    for d in "$SANDBOX_DIR"/*; do
      [[ -d "$d/rootfs" ]] || continue
      found=1; name="${d##*/}"; distro="unknown"
      [[ -f "$d/distro" ]] && IFS= read -r distro < "$d/distro"
      printf '  %s%-24s%s %s\n' "$CYAN" "$name" "$RESET" "$distro"
    done
    [[ $found -eq 1 ]] || say "  ${GRAY}No sandboxes created yet.${RESET}"
    say "${DIM}Tip: attach a Railway Volume and set MIRACLE_HOME to its mount path for persistence.${RESET}"
  fi
}

open_shell() {
  local name="${1:-}" rootfs prootbin shell
  [[ -n "$name" ]] || die "Usage: $0 shell NAME"
  require_name "$name"
  if incus_ready && incus info "$name" >/dev/null 2>&1; then
    if incus exec "$name" -- /bin/bash --login; then return 0; else warn "bash shell failed; trying /bin/sh."; incus exec "$name" -- /bin/sh; return; fi
  fi
  is_sandbox "$name" || die "No reachable Incus instance or PRoot sandbox named '$name'."
  prootbin="$BIN_DIR/proot"; [[ -x "$prootbin" ]] || prootbin="$(command -v proot || true)"
  [[ -n "$prootbin" && -x "$prootbin" ]] || die "PRoot is missing. Run: $0 create $name"
  rootfs="$SANDBOX_DIR/$name/rootfs"
  if [[ -x "$rootfs/bin/bash" ]]; then shell=/bin/bash; else shell=/bin/sh; fi
  warn "Entering userspace sandbox '$name'; it is not a VM and has no independent kernel/systemd PID 1."
  exec "$prootbin" -R "$rootfs" "$shell" --login
}

run_inside() {
  local name="${1:-}"; shift || true
  [[ -n "$name" && $# -gt 0 ]] || die "Usage: $0 run NAME COMMAND [ARG ...]"
  require_name "$name"
  if incus_ready && incus info "$name" >/dev/null 2>&1; then exec incus exec "$name" -- "$@"; fi
  is_sandbox "$name" || die "No reachable Incus instance or PRoot sandbox named '$name'."
  local prootbin="$BIN_DIR/proot"
  [[ -x "$prootbin" ]] || prootbin="$(command -v proot || true)"
  [[ -n "$prootbin" && -x "$prootbin" ]] || die "PRoot is missing."
  exec "$prootbin" -R "$SANDBOX_DIR/$name/rootfs" "$@"
}

instance_action() {
  local action="${1:-}" name="${2:-}"
  [[ -n "$action" && -n "$name" ]] || die "Usage: $0 {start|stop|restart} NAME"
  require_name "$name"
  incus_ready || die "Start/stop/restart requires an Incus daemon. PRoot sandboxes are interactive processes, not background VMs."
  incus info "$name" >/dev/null 2>&1 || die "Incus instance '$name' not found."
  case "$action" in
    start) incus start "$name" ;;
    stop) incus stop "$name" ;;
    restart) incus restart "$name" ;;
    *) die "Unknown action: $action" ;;
  esac
  ok "${name}: ${action} request completed."
}

remove_instance() {
  local name="${1:-}" answer
  [[ -n "$name" ]] || die "Usage: $0 remove NAME"
  require_name "$name"
  if incus_ready && incus info "$name" >/dev/null 2>&1; then
    if [[ -t 0 ]]; then
      read -r -p "Permanently delete Incus instance '$name' and its data? [y/N] " answer
      [[ "$answer" == y || "$answer" == Y ]] || { info "Cancelled."; return 0; }
    else
      [[ "${MIRACLE_CONFIRM_DELETE:-}" == "$name" ]] || die "Non-interactive delete requires MIRACLE_CONFIRM_DELETE=$name"
    fi
    incus delete --force "$name" && ok "Incus instance '$name' removed."
    return
  fi
  is_sandbox "$name" || die "No reachable Incus instance or PRoot sandbox named '$name'."
  if [[ -t 0 ]]; then
    read -r -p "Permanently remove sandbox '$name' and its downloaded root filesystem? [y/N] " answer
    [[ "$answer" == y || "$answer" == Y ]] || { info "Cancelled."; return 0; }
  else
    [[ "${MIRACLE_CONFIRM_DELETE:-}" == "$name" ]] || die "Non-interactive delete requires MIRACLE_CONFIRM_DELETE=$name"
  fi
  rm -rf -- "$SANDBOX_DIR/$name"
  ok "Sandbox '$name' removed."
}

setup_docker() {
  local name="${1:-}"
  [[ -n "$name" ]] || die "Usage: $0 docker-setup NAME"
  require_name "$name"
  incus_ready && incus info "$name" >/dev/null 2>&1 || die "Docker setup is only offered for an actual Incus system container."
  info "Installing Docker Engine packages inside '$name'…"
  incus exec "$name" -- /bin/sh -lc 'command -v apt-get >/dev/null 2>&1 || { echo "This helper currently supports Debian/Ubuntu images only." >&2; exit 2; }; export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y docker.io'
  ok "Docker packages installed. Starting the daemon may still depend on Incus/host kernel and cgroup policy."
  incus exec "$name" -- /bin/sh -lc 'systemctl enable --now docker || service docker start || true'
  incus exec "$name" -- /bin/sh -lc 'docker info >/dev/null 2>&1 && echo "Docker daemon is responding." || { echo "Docker CLI installed, but daemon is not available." >&2; exit 1; }'
}

show_help() {
  cat <<EOF
${APP} · v${VERSION}

Usage:
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL)                 Open the menu
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) check            Diagnose Railway capabilities
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) create NAME [debian|ubuntu] [CPU] [RAM_MiB] [DISK_GiB]
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) list              List available environments
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) shell NAME        Enter an environment
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) run NAME COMMAND [ARG ...]
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) start NAME
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) stop NAME
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) restart NAME
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) docker-setup NAME Install Docker inside a real Incus container
  bash <(curl -fsSL YOUR_RAW_GITHUB_URL) remove NAME

Backends:
  • Reachable Incus daemon: system containers with systemd; Docker nesting depends on host capabilities.
  • No Incus daemon: PRoot Linux userspace sandbox (Debian/Ubuntu). This is NOT a VM and cannot run systemd as PID 1 or a Docker daemon.

Environment:
  MIRACLE_HOME=/path   Store images and environments here (use a Railway Volume path for persistence).
  MIRACLE_NO_ANIMATION=1  Disable the menu startup animation.
  NO_COLOR=1           Disable ANSI colors.

Railway caveat: no portable script can grant missing kernel capabilities, privileged mode, cgroup control,
or host Docker socket access. The diagnostic command reports what the current container actually exposes.
EOF
}

menu() {
  local choice name distro cpu ram disk cmd
  prepare_dirs
  startup_animation
  while true; do
    banner
    printf '%s  01%s  Create environment\n' "$PINK" "$RESET"
    printf '%s  02%s  List environments\n' "$PINK" "$RESET"
    printf '%s  03%s  Enter shell\n' "$PINK" "$RESET"
    printf '%s  04%s  Run command in environment\n' "$PINK" "$RESET"
    printf '%s  05%s  Start / stop / restart (Incus only)\n' "$PINK" "$RESET"
    printf '%s  06%s  Install Docker (Incus system container only)\n' "$PINK" "$RESET"
    printf '%s  07%s  Delete environment\n' "$PINK" "$RESET"
    printf '%s  08%s  Runtime diagnostics\n' "$PINK" "$RESET"
    printf '%s  00%s  Exit\n' "$PINK" "$RESET"
    hr
    if incus_ready; then printf '  Backend: %sIncus reachable%s\n' "$GREEN" "$RESET"; else printf '  Backend: %sNo local Incus · PRoot fallback only%s\n' "$YELLOW" "$RESET"; fi
    read -r -p "  ${CYAN}Select an option › ${RESET}" choice || break
    case "$choice" in
      1|01)
        read -r -p "  Instance/sandbox name [miracle-debian]: " name || continue; name="${name:-miracle-debian}"
        read -r -p "  OS (debian/ubuntu) [debian]: " distro || continue; distro="${distro:-debian}"
        if incus_ready; then
          read -r -p "  CPU cores [2]: " cpu || continue; cpu="${cpu:-2}"
          read -r -p "  RAM MiB [2048]: " ram || continue; ram="${ram:-2048}"
          read -r -p "  Disk GiB [10]: " disk || continue; disk="${disk:-10}"
          incus_create "$name" "$distro" "$cpu" "$ram" "$disk" || true
        else
          create_sandbox "$name" "$distro" || true
        fi
        read -r -p "  Press Enter to continue… " _ || true ;;
      2|02) list_instances; read -r -p "  Press Enter to continue… " _ || true ;;
      3|03) read -r -p "  Environment name: " name || continue; open_shell "$name" || true ;;
      4|04)
        read -r -p "  Environment name: " name || continue
        read -r -p "  Command to run (example: cat /etc/os-release): " cmd || continue
        [[ -n "$cmd" ]] && run_inside "$name" /bin/sh -lc "$cmd" || true
        read -r -p "  Press Enter to continue… " _ || true ;;
      5|05)
        read -r -p "  Action (start/stop/restart): " cmd || continue
        read -r -p "  Instance name: " name || continue
        instance_action "$cmd" "$name" || true
        read -r -p "  Press Enter to continue… " _ || true ;;
      6|06) read -r -p "  Incus instance name: " name || continue; setup_docker "$name" || true; read -r -p "  Press Enter to continue… " _ || true ;;
      7|07) read -r -p "  Environment name: " name || continue; remove_instance "$name" || true; read -r -p "  Press Enter to continue… " _ || true ;;
      8|08) check_report; read -r -p "  Press Enter to continue… " _ || true ;;
      0|00|q|Q) say "${PURPLE}Miracle Cloud signed off.${RESET}"; break ;;
      *) warn "Choose one of the listed options."; sleep 0.5 ;;
    esac
    printf '\n'
  done
}

main() {
  case "${1:-}" in
    help|-h|--help) show_help ;;
    version|-v|--version) say "Miracle Cloud Railway Edition $VERSION" ;;
    check|diagnose) check_report ;;
    create) shift; create_instance "${1:-}" "${2:-debian}" "${3:-2}" "${4:-2048}" "${5:-10}" ;;
    list|ls) list_instances ;;
    shell|enter) shift; open_shell "${1:-}" ;;
    run) shift; run_inside "${1:-}" "${@:2}" ;;
    start|stop|restart) action="$1"; shift; instance_action "$action" "${1:-}" ;;
    docker-setup) shift; setup_docker "${1:-}" ;;
    remove|delete|rm) shift; remove_instance "${1:-}" ;;
    "") menu ;;
    *) show_help >&2; exit 2 ;;
  esac
}

main "$@"
