#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                        MIRACLE CLOUD VM MANAGER v7.0                               ║
# ║              Premium Multi-VM Virtualization Control                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Premium palette (Obsidian / Electric Violet / Gold / Emerald)
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_VIOLET="\033[1;35m"
C_PURPLE="\033[0;35m"
C_GOLD="\033[1;33m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_RED="\033[1;31m"
C_WHITE="\033[1;37m"
C_GRAY="\033[1;90m"

WORK_TMP_DIR=""
KVM_AVAILABLE=false
KVM_STATUS_LABEL="UNAVAILABLE (TCG MODE)"

detect_kvm_support() {
    if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
        if command -v kvm-ok >/dev/null 2>&1; then
            if kvm-ok >/dev/null 2>&1; then
                KVM_AVAILABLE=true
                KVM_STATUS_LABEL="ENABLED (HARDWARE KVM)"
                return 0
            fi
        else
            KVM_AVAILABLE=true
            KVM_STATUS_LABEL="ENABLED (HARDWARE KVM)"
            return 0
        fi
    fi
    KVM_AVAILABLE=false
    KVM_STATUS_LABEL="FALLBACK (SOFTWARE TCG)"
}

print_status() {
    local type=$1
    local message=$2

    case "$type" in
        "INFO")    echo -e "${C_CYAN}[MIRACLE • INFO]${C_RESET} ${C_WHITE}${message}${C_RESET}" ;;
        "WARN")    echo -e "${C_GOLD}[MIRACLE • WARN]${C_RESET} ${message}" ;;
        "ERROR")   echo -e "${C_RED}[MIRACLE • ERR ]${C_RESET} ${message}" ;;
        "SUCCESS") echo -e "${C_GREEN}[MIRACLE • OK  ]${C_RESET} ${message}" ;;
        "INPUT")   echo -e "${C_VIOLET}[MIRACLE • >>> ]${C_RESET} ${C_GOLD}${message}${C_RESET}" ;;
        *)         echo -e "${C_VIOLET}[${type}]${C_RESET} ${message}" ;;
    esac
}

display_header() {
    clear
    tput civis 2>/dev/null || true

    printf "${C_VIOLET}╔════════════════════════════════════════════════════════════════════════════════════╗${C_RESET}\n"
    printf "${C_VIOLET}║${C_GOLD}                        ⚡ MIRACLE CLOUD VM MANAGER v7.0 ⚡                                ${C_VIOLET}║${C_RESET}\n"
    printf "${C_VIOLET}║${C_GRAY}              Multi-OS QEMU/KVM • Terminal • Networking • CPU Profiles                 ${C_VIOLET}║${C_RESET}\n"
    printf "${C_VIOLET}╚════════════════════════════════════════════════════════════════════════════════════╝${C_RESET}\n"

    cat << 'EOF'
  __  __ ___ ____      _    ____ _     ____  __     ____  __
 |  \/  |_ _|  _ \    / \  / ___| |   | ____| \ \   / /  \/  |
 | |\/| || || |_) |  / _ \| |   | |   |  _|    \ \ / /| |\/| |
 | |  | || ||  _ <  / ___ \ |___| |___| |___    \ V / | |  | |
 |_|  |_|___|_| \_\/_/   \_\____|_____|_____|    \_/  |_|  |_|
EOF

    printf "                  ${C_GOLD}✦ POWERED BY MIRACLE VM • RYZEN & CLOUD-INIT ✦${C_RESET}\n\n"

    printf "${C_VIOLET}┌─ SYSTEM TELEMETRY ────────────────────────────────────────────────────────────────┐${C_RESET}\n"
    printf "${C_VIOLET}│${C_RESET} ${C_CYAN}Host / User   ${C_RESET}: ${C_WHITE}%s@%s${C_RESET}\n" "$(whoami)" "$(hostname)"
    printf "${C_VIOLET}│${C_RESET} ${C_CYAN}Kernel / Arch ${C_RESET}: ${C_WHITE}%s (%s)${C_RESET}\n" "$(uname -r)" "$(uname -m)"
    printf "${C_VIOLET}│${C_RESET} ${C_CYAN}Accel Mode    ${C_RESET}: ${C_GREEN}%s${C_RESET}\n" "$KVM_STATUS_LABEL"
    printf "${C_VIOLET}│${C_RESET} ${C_CYAN}Timestamp     ${C_RESET}: ${C_WHITE}%s • %s${C_RESET}\n" "$(date '+%d %b %Y')" "$(date '+%I:%M:%S %p')"
    printf "${C_VIOLET}└────────────────────────────────────────────────────────────────────────────────────┘${C_RESET}\n\n"
}

validate_input() {
    local type=$1
    local value=$2

    case "$type" in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ]; then
                print_status "ERROR" "Must be a positive number"
                return 1
            fi
            ;;
        "size")
