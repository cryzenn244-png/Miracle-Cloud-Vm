#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                        MIRACLE CLOUD VM MANAGER v8.0                               ║
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

startup_animation() {
    [[ -t 1 && -t 0 ]] || return 0
    local frames=('INITIALIZING MIRACLE CORE' 'VERIFYING VIRTUALIZATION' 'LOADING CONTROL MODULES')
    printf "\033[?25l"
    for i in 0 1 2; do
        printf "\r${C_VIOLET}╭─ MIRACLE CLOUD V8 ─────────────────────────────────────────╮${C_RESET}\n"
        printf "${C_VIOLET}│${C_RESET} ${C_CYAN}%-58s${C_RESET}${C_VIOLET}│${C_RESET}\n" "${frames[$i]}"
        printf "${C_VIOLET}│${C_RESET} ["
        for j in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19; do
            if (( j <= (i+1)*6 )); then printf "${C_PURPLE}█${C_RESET}"; else printf "${C_GRAY}·${C_RESET}"; fi
        done
        printf "] ${C_GOLD}%2d%%${C_RESET}\n" "$(((i+1)*33))"
        printf "${C_VIOLET}╰────────────────────────────────────────────────────────────╯${C_RESET}\n"
        sleep 1
        printf "\033[4A"
    done
    printf "\033[?25h"
    clear 2>/dev/null || true
}

display_header() {
    clear 2>/dev/null || true
    tput civis 2>/dev/null || true

    printf "${C_VIOLET}╔════════════════════════════════════════════════════════════════════════════════════╗${C_RESET}\n"
    printf "${C_VIOLET}║${C_GOLD}                        ⚡ MIRACLE CLOUD VM MANAGER v8.0 ⚡                                ${C_VIOLET}║${C_RESET}\n"
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
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "Must be a size with unit (e.g., 20G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "forwards")
            if [[ -z "$value" ]]; then
                return 0
            fi
            IFS=',' read -ra pairs <<< "$value"
            for pair in "${pairs[@]}"; do
                if ! [[ "$pair" =~ ^[0-9]+:[0-9]+$ ]]; then
                    print_status "ERROR" "Port forwards must use host:guest format separated by commas (e.g., 8080:80,25565:25565)"
                    return 1
                fi
                local hp="${pair%%:*}"
                local gp="${pair##*:}"
                if [ "$hp" -lt 1 ] || [ "$hp" -gt 65535 ] || [ "$gp" -lt 1 ] || [ "$gp" -gt 65535 ]; then
                    print_status "ERROR" "Ports in '$pair' must be between 1 and 65535"
                    return 1
                fi
            done
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "Name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Username must start with a lowercase letter or underscore and contain only letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
    esac
    return 0
}

check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img" "openssl")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing required tools: ${missing_deps[*]}"
        print_status "INFO" "Install on Ubuntu/Debian with: sudo apt update && sudo apt install -y qemu-system-x86 cloud-image-utils wget openssl"
        exit 1
    fi
}

cleanup() {
    tput cnorm 2>/dev/null || printf "\033[?25h"
    if [[ -n "${WORK_TMP_DIR:-}" && -d "$WORK_TMP_DIR" ]]; then
        rm -rf "$WORK_TMP_DIR"
    fi
}

get_vm_list() {
    if [[ ! -d "$VM_DIR" ]]; then
        return 0
    fi
    find "$VM_DIR" -maxdepth 1 -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"

    if [[ -f "$config_file" ]]; then
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS
        unset CPU_LABEL CPU_MODEL CPU_FLAGS IMG_FILE SEED_FILE CREATED MIRACLE_PLUS AUTOSTART VNC_PASSWORD

        # shellcheck disable=SC1090
        source "$config_file"
        CPU_LABEL="${CPU_LABEL:-Ryzen EPYC Genoa (Zen 4 Class)}"
        CPU_MODEL="${CPU_MODEL:-EPYC-Genoa-v1}"
        CPU_FLAGS="${CPU_FLAGS:-+ibpb,+virt-ssbd}"
        MIRACLE_PLUS="${MIRACLE_PLUS:-false}"
        AUTOSTART="${AUTOSTART:-false}"
        VNC_PASSWORD="${VNC_PASSWORD:-}"
        return 0
    else
        print_status "ERROR" "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"

    umask 077
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
        printf 'MIRACLE_PLUS=%q\n' "${MIRACLE_PLUS:-false}"
        printf 'AUTOSTART=%q\n' "${AUTOSTART:-false}"
        printf 'VNC_PASSWORD=%q\n' "${VNC_PASSWORD:-}"
    } > "$config_file"
    chmod 600 "$config_file"

    print_status "SUCCESS" "Saved configuration to $config_file"
}

select_ryzen_processor() {
    local profiles=(
      'AMD Ryzen 9 9950X (Zen 5 class; approximate QEMU model)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
      'AMD Ryzen 9 7950X|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
      'AMD Ryzen 9 7950X3D (3D V-Cache is not emulated)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
      'AMD Ryzen 7 9800X3D (3D V-Cache is not emulated)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
      'AMD Ryzen 7 9700X (Zen 5 class; approximate QEMU model)|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
      'AMD Ryzen 9 7900X|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
      'AMD Ryzen 7 7700X|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
      'AMD Ryzen 9 5950X|EPYC-Milan-v2|+ibpb,+virt-ssbd'
      'AMD Ryzen 9 5900X|EPYC-Milan-v2|+ibpb,+virt-ssbd'
      'AMD Ryzen 7 5800X3D (3D V-Cache is not emulated)|EPYC-Milan-v2|+ibpb,+virt-ssbd'
      'AMD Ryzen 7 5800X|EPYC-Milan-v2|+ibpb,+virt-ssbd'
      'Intel Core Ultra 9 285K (approximate server CPU model)|SapphireRapids|'
      'Intel Core Ultra 7 265K (approximate server CPU model)|SapphireRapids|'
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
      'Intel Xeon E-2388G (approximate QEMU model)|Cascadelake-Server|'
      'Intel Xeon E-2488 (approximate QEMU model)|Cascadelake-Server|'
      'Intel Xeon Gold 6442Y|SapphireRapids|'
      'Intel Xeon Gold 5317|Icelake-Server|'
      'Existing: AMD EPYC Genoa|EPYC-Genoa-v1|+ibpb,+virt-ssbd'
      'Existing: AMD EPYC Milan|EPYC-Milan-v2|+ibpb,+virt-ssbd'
      'Existing: AMD EPYC Rome|EPYC-Rome-v4|+ibpb,+virt-ssbd'
      'Existing: AMD EPYC Classic|EPYC-v4|+ibpb,+virt-ssbd'
      'Generic x86-64 (portable)|qemu64|'
      'Host passthrough (KVM only; actual host CPU)|host|+virt-ssbd'
    )
    print_status "INFO" "Select CPU profile. Retail labels are mapped to available QEMU models; retail-specific features are not emulated."
    local i=1
    for profile in "${profiles[@]}"; do
        IFS='|' read -r label model flags <<< "$profile"
        printf "  ${C_GOLD}%2d)${C_RESET} ${C_WHITE}%s${C_RESET} ${C_GRAY}[QEMU: %s]${C_RESET}\n" "$i" "$label" "$model"
        ((i+=1))
    done
    while true; do
        read -r -p "$(print_status INPUT "Choose CPU profile (1-${#profiles[@]}, default 1): ")" cpu_choice
        cpu_choice="${cpu_choice:-1}"
        if [[ "$cpu_choice" =~ ^[0-9]+$ ]] && (( cpu_choice >= 1 && cpu_choice <= ${#profiles[@]} )); then
            IFS='|' read -r CPU_LABEL CPU_MODEL CPU_FLAGS <<< "${profiles[$((cpu_choice-1))]}"
            if [[ "$CPU_MODEL" == host && "$KVM_AVAILABLE" != true ]]; then
                print_status ERROR "Host passthrough requires working KVM. Choose a portable model instead."
                continue
            fi
            print_status SUCCESS "Selected $CPU_LABEL -> QEMU model $CPU_MODEL"
            return 0
        fi
        print_status ERROR "Invalid selection."
    done
}

qemu_cpu_model_exists() {
    local model="$1"
    [[ "$model" == host ]] && [[ "$KVM_AVAILABLE" == true ]] && return 0
    qemu-system-x86_64 -cpu help 2>/dev/null | grep -Eiq "(^|[[:space:]])${model}([[:space:]]|$)"
}

build_cpu_arg() {
    local model="$1" flags="$2" chosen="$1"
    if [[ "$KVM_AVAILABLE" != true ]]; then
        case "$model" in
            host) chosen="qemu64" ;;
            *EPYC*|*epyc*)
                for candidate in EPYC-Milan-v2 EPYC-Rome-v2 EPYC-Rome-v1 EPYC qemu64; do
                    if qemu_cpu_model_exists "$candidate"; then chosen="$candidate"; break; fi
                done ;;
            SapphireRapids|Icelake-Server|Cascadelake-Server|Skylake-Server)
                for candidate in Icelake-Server Cascadelake-Server Skylake-Server Broadwell qemu64; do
                    if qemu_cpu_model_exists "$candidate"; then chosen="$candidate"; break; fi
                done ;;
            *) qemu_cpu_model_exists "$model" || chosen="qemu64" ;;
        esac
        printf '%s' "$chosen"
        return 0
    fi
    if [[ "$model" != host ]] && ! qemu_cpu_model_exists "$model"; then
        print_status WARN "QEMU model '$model' is unavailable; selecting a compatible fallback." >&2
        case "$model" in
            *EPYC*|*epyc*)
                chosen="qemu64"
                for candidate in EPYC-Genoa-v1 EPYC-Milan-v2 EPYC-Rome-v2 EPYC-Rome-v1 EPYC qemu64; do
                    if qemu_cpu_model_exists "$candidate"; then chosen="$candidate"; break; fi
                done ;;
            SapphireRapids|Icelake-Server|Cascadelake-Server|Skylake-Server)
                chosen="qemu64"
                for candidate in SapphireRapids Icelake-Server Cascadelake-Server Skylake-Server Broadwell qemu64; do
                    if qemu_cpu_model_exists "$candidate"; then chosen="$candidate"; break; fi
                done ;;
            *) chosen="qemu64" ;;
        esac
    fi
    if [[ -n "$flags" && "$chosen" != qemu64 ]]; then printf '%s,%s' "$chosen" "$flags"; else printf '%s' "$chosen"; fi
}

create_new_vm() {
    MIRACLE_PLUS=false
    AUTOSTART=false
    VNC_PASSWORD=""
    print_status "INFO" "Launching Miracle VM Creation Wizard..."

    print_status "INFO" "Select an Operating System:"
    local os_keys=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        os_keys[$i]="$os"
        printf "  ${C_GOLD}%2d)${C_RESET} ${C_WHITE}%s${C_RESET}\n" "$i" "$os"
        i=$((i + 1))
    done

    while true; do
        read -p "$(print_status "INPUT" "Enter OS choice (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_keys[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
            break
        else
            print_status "ERROR" "Invalid selection. Try again."
        fi
    done

    select_ryzen_processor

    while true; do
        read -p "$(print_status "INPUT" "Enter VM name (default: $DEFAULT_HOSTNAME): ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status "ERROR" "VM '$VM_NAME' already exists"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enter hostname (default: $VM_NAME): ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        if validate_input "name" "$HOSTNAME"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enter username (default: $DEFAULT_USERNAME): ")" USERNAME
        USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
        if validate_input "username" "$USERNAME"; then
            break
        fi
    done

    while true; do
        read -r -s -p "$(print_status "INPUT" "Set a strong VM password (input hidden): ")" PASSWORD
        echo
        if [ -n "$PASSWORD" ]; then
            break
        else
            print_status "ERROR" "Password cannot be empty"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Disk size (default: 20G): ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-20G}"
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Memory in MB (default: 2048): ")" MEMORY
        MEMORY="${MEMORY:-2048}"
        if validate_input "number" "$MEMORY"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Number of vCPUs (default: 2): ")" CPUS
        CPUS="${CPUS:-2}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "SSH Port (default: 2222): ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        if validate_input "port" "$SSH_PORT"; then
            if ss -tln 2>/dev/null | grep -q ":${SSH_PORT} "; then
                print_status "ERROR" "Port $SSH_PORT is already in use"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enable GUI mode? (y/n, default: n): ")" gui_input
        gui_input="${gui_input:-n}"
        if [[ "$gui_input" =~ ^[Yy]$ ]]; then
            GUI_MODE=true
            break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
            GUI_MODE=false
            break
        else
            print_status "ERROR" "Please answer y or n"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Additional port forwards (e.g., 8080:80,3000:3000 or Enter for none): ")" PORT_FORWARDS
        if validate_input "forwards" "$PORT_FORWARDS"; then
            break
        fi
    done

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"

    setup_vm_image || return 1
    save_vm_config || return 1
}

setup_vm_image() {
    print_status "INFO" "Preparing disk image and cloud-init seed for '$VM_NAME'..."
    mkdir -p "$VM_DIR"

    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "INFO" "Downloading cloud image from $IMG_URL..."
        if ! wget --progress=bar:force "$IMG_URL" -O "${IMG_FILE}.tmp"; then
            print_status "ERROR" "Failed to download image from $IMG_URL"
            rm -f "${IMG_FILE}.tmp"
            return 1
        fi
        mv "${IMG_FILE}.tmp" "$IMG_FILE"
    else
        print_status "INFO" "Reusing existing disk image: $IMG_FILE"
    fi

    if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" >/dev/null 2>&1; then
        print_status "ERROR" "Disk resize failed. Existing image was NOT replaced or deleted: $IMG_FILE"
        return 1
    fi

    local stage_dir
    stage_dir="$(mktemp -d "${WORK_TMP_DIR}/seed_XXXXXX")"
    local pass_hash
    pass_hash="$(openssl passwd -6 "$PASSWORD" | tr -d '\n')"

    cat > "$stage_dir/user-data" <<EOF
#cloud-config
hostname: $HOSTNAME
manage_etc_hosts: true
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $pass_hash
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF
    if [[ "${MIRACLE_PLUS:-false}" == true ]]; then
        cat >> "$stage_dir/user-data" <<'CLOUDINIT'
runcmd:
  - [bash, -lc, "apt-get update && apt-get upgrade -y && (apt-get install -y fastfetch || true) && (apt-get install -y neofetch || true) && (apt-get install -y curl wget git ca-certificates qemu-guest-agent htop nano vim tmux unzip zip rsync sudo ufw fail2ban || true)"]
CLOUDINIT
    fi

    cat > "$stage_dir/meta-data" <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if ! cloud-localds "$SEED_FILE" "$stage_dir/user-data" "$stage_dir/meta-data"; then
        print_status "ERROR" "Failed to generate cloud-init ISO at $SEED_FILE"
        rm -rf "$stage_dir"
        return 1
    fi

    rm -rf "$stage_dir"
    print_status "SUCCESS" "VM image and cloud-init seed ready."
}

start_vm() {
    local vm_name=$1

    if ! load_vm_config "$vm_name"; then
        return 1
    fi

    if is_vm_running "$vm_name"; then
        print_status "WARN" "VM '$vm_name' is already running."
        return 0
    fi

    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "ERROR" "VM image file not found: $IMG_FILE"
        return 1
    fi

    if [[ ! -f "$SEED_FILE" ]]; then
        print_status "WARN" "Seed file missing; regenerating..."
        setup_vm_image
    fi

    detect_kvm_support
    local effective_cpu
    effective_cpu="$(build_cpu_arg "$CPU_MODEL" "$CPU_FLAGS")"

    print_status "INFO" "Booting VM: $vm_name ($OS_TYPE $CODENAME)"
    print_status "INFO" "Processor : $CPU_LABEL -> QEMU CPU: $effective_cpu"
    print_status "INFO" "Accel Mode: $KVM_STATUS_LABEL"
    print_status "INFO" "SSH Access: ssh -p $SSH_PORT $USERNAME@127.0.0.1 (use the password you set; not displayed)"
    local pid_file="$VM_DIR/$vm_name.pid"
    local monitor_file="$VM_DIR/$vm_name.monitor"
    local serial_log="$VM_DIR/$vm_name.serial.log"
    local qemu_log="$VM_DIR/$vm_name.qemu.log"
    local vnc_display=0 found_vnc=false
    rm -f "$pid_file" "$monitor_file"
    if [[ "$GUI_MODE" == true ]]; then
        for candidate_display in {1..99}; do
            if ! ss -ltn 2>/dev/null | grep -Eq "127\.0\.0\.1:$((5900+candidate_display))[[:space:]]"; then vnc_display="$candidate_display"; found_vnc=true; break; fi
        done
        if [[ "$found_vnc" != true ]]; then print_status ERROR "No free loopback VNC display was found."; return 1; fi
    fi

    local qemu_cmd=(
        qemu-system-x86_64
        -name "$vm_name"
        -daemonize
        -pidfile "$pid_file"
        -D "$qemu_log"
        -monitor "unix:$monitor_file,server=on,wait=off"
        -m "$MEMORY"
        -smp "$CPUS"
        -cpu "$effective_cpu"
        -drive "file=$IMG_FILE,format=qcow2,if=virtio"
        -drive "file=$SEED_FILE,format=raw,if=virtio"
        -boot order=c
        -device "virtio-net-pci,netdev=net0"
        -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
    )

    if [[ "$KVM_AVAILABLE" == true ]]; then
        qemu_cmd+=(-enable-kvm)
    fi

    if [[ -n "${PORT_FORWARDS:-}" ]]; then
        local net_idx=1
        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
        for forward in "${forwards[@]}"; do
            IFS=':' read -r host_port guest_port <<< "$forward"
            qemu_cmd+=(-device "virtio-net-pci,netdev=net${net_idx}")
            qemu_cmd+=(-netdev "user,id=net${net_idx},hostfwd=tcp::${host_port}-:${guest_port}")
            net_idx=$((net_idx + 1))
        done
    fi

    if [[ "$GUI_MODE" == true ]]; then
        qemu_cmd+=(-vga virtio -display none -vnc "127.0.0.1:${vnc_display},password=on")
    else
        qemu_cmd+=(-display none -serial "file:$serial_log")
    fi

    qemu_cmd+=(
        -device virtio-balloon-pci
        -object "rng-random,filename=/dev/urandom,id=rng0"
        -device "virtio-rng-pci,rng=rng0"
    )

    if ! "${qemu_cmd[@]}"; then
        print_status ERROR "QEMU failed to start. Review $qemu_log if it exists."
        rm -f "$pid_file"
        return 1
    fi
    sleep 1
    if is_vm_running "$vm_name"; then
        print_status SUCCESS "VM '$vm_name' is running in the background. Log: $qemu_log"
        if [[ "$GUI_MODE" == true ]]; then
            if [[ -z "${VNC_PASSWORD:-}" ]]; then VNC_PASSWORD="$(openssl rand -hex 4)"; save_vm_config; fi
            if command -v socat >/dev/null 2>&1; then printf 'change vnc password %s\n' "$VNC_PASSWORD" | socat - "UNIX-CONNECT:$monitor_file" >/dev/null 2>&1 || true; fi
            printf '%s\n' "$vnc_display" > "$VM_DIR/$vm_name.vnc-display"
            print_status INFO "VNC listens on loopback 127.0.0.1:$((5900+vnc_display)); VNC password is stored in the mode-600 VM config. Use the VNC Tunnel menu to publish it."
        fi
    else
        print_status ERROR "QEMU returned but VM process was not detected. Check $qemu_log"
        return 1
    fi
}

delete_vm() {
    local vm_name=$1

    print_status "WARN" "This will permanently delete VM '$vm_name' and its disk/seed files!"
    read -p "$(print_status "INPUT" "Confirm deletion? (y/N): ")" -n 1 -r
    echo
    if [[ ${REPLY:-} =~ ^[Yy]$ ]]; then
        if is_vm_running "$vm_name"; then
            stop_vm "$vm_name"
        fi
        if load_vm_config "$vm_name"; then
            rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf"
            print_status "SUCCESS" "VM '$vm_name' deleted."
        fi
    else
        print_status "INFO" "Deletion cancelled."
    fi
}

show_vm_info() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        echo
        printf "${C_VIOLET}╔════════════════════ VM DOSSIER: %-48s ╗${C_RESET}\n" "$vm_name"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}OS / Release   ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$OS_TYPE ($CODENAME)"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}Processor      ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$CPU_LABEL"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}CPU Model/Flags${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$CPU_MODEL (${CPU_FLAGS:-none})"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}Hostname/User  ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$HOSTNAME / $USERNAME"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}Password       ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "[hidden]"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}SSH Port       ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$SSH_PORT"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}Resources      ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "${MEMORY} MB RAM • ${CPUS} vCPU • ${DISK_SIZE} Disk"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}GUI / Forwards ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "GUI=$GUI_MODE • Ports=${PORT_FORWARDS:-None}"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}Created        ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$CREATED"
        printf "${C_VIOLET}╚════════════════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
    fi
}

is_vm_running() {
    local vm_name=$1
    local pid_file="$VM_DIR/$vm_name.pid"
    if [[ -r "$pid_file" ]]; then
        local pid
        pid="$(cat "$pid_file" 2>/dev/null || true)"
        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then return 0; fi
    fi
    local img_path="$VM_DIR/$vm_name.img"
    pgrep -f "qemu-system-x86_64.*${img_path}" >/dev/null 2>&1
}

stop_vm() {
    local vm_name=$1
    stop_vnc_tunnel "$vm_name" 2>/dev/null || true
    if ! load_vm_config "$vm_name"; then return 1; fi
    if ! is_vm_running "$vm_name"; then
        print_status INFO "VM '$vm_name' is not running."
        return 0
    fi
    local pid_file="$VM_DIR/$vm_name.pid" pid=""
    [[ -r "$pid_file" ]] && pid="$(cat "$pid_file" 2>/dev/null || true)"
    print_status INFO "Requesting graceful shutdown for '$vm_name'..."
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        for _ in {1..10}; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
        if kill -0 "$pid" 2>/dev/null; then
            read -r -p "VM did not stop promptly. Force stop it? (y/N): " force
            if [[ "${force,,}" == y || "${force,,}" == yes ]]; then kill -KILL "$pid" 2>/dev/null || true; else return 1; fi
        fi
    else
        print_status WARN "PID file is missing/stale; process matching fallback will be used."
        pkill -TERM -f "qemu-system-x86_64.*$VM_DIR/$vm_name.img" 2>/dev/null || true
    fi
    rm -f "$pid_file" "$VM_DIR/$vm_name.monitor"
    print_status SUCCESS "Stop request sent for '$vm_name'."
}

edit_vm_config() {
    local vm_name=$1

    if ! load_vm_config "$vm_name"; then
        return 1
    fi

    while true; do
        echo
        print_status "INFO" "Editing VM '$vm_name' (${C_GOLD}${CPU_LABEL}${C_RESET}):"
        echo "  1) Hostname"
        echo "  2) Username"
        echo "  3) Password"
        echo "  4) SSH Port"
        echo "  5) GUI Mode"
        echo "  6) Port Forwards"
        echo "  7) Memory (MB)"
        echo "  8) CPU Count"
        echo "  9) Disk Size"
        echo " 10) Processor Profile (Ryzen / EPYC)"
        echo "  0) Save & Return"

        read -p "$(print_status "INPUT" "Select option: ")" edit_choice

        case "$edit_choice" in
            1)
                while true; do
                    read -p "$(print_status "INPUT" "New hostname (current: $HOSTNAME): ")" new_val
                    new_val="${new_val:-$HOSTNAME}"
                    if validate_input "name" "$new_val"; then HOSTNAME="$new_val"; break; fi
                done
                ;;
            2)
                while true; do
                    read -p "$(print_status "INPUT" "New username (current: $USERNAME): ")" new_val
                    new_val="${new_val:-$USERNAME}"
                    if validate_input "username" "$new_val"; then USERNAME="$new_val"; break; fi
                done
                ;;
            3)
                while true; do
                    read -s -p "$(print_status "INPUT" "New password (current: hidden, Enter to keep): ")" new_val
                    echo
                    new_val="${new_val:-$PASSWORD}"
                    if [ -n "$new_val" ]; then PASSWORD="$new_val"; break; fi
                done
                ;;
            4)
                while true; do
                    read -p "$(print_status "INPUT" "New SSH port (current: $SSH_PORT): ")" new_val
                    new_val="${new_val:-$SSH_PORT}"
                    if validate_input "port" "$new_val"; then
                        if [ "$new_val" != "$SSH_PORT" ] && ss -tln 2>/dev/null | grep -q ":${new_val} "; then
                            print_status "ERROR" "Port $new_val is already in use"
                        else
                            SSH_PORT="$new_val"
                            break
                        fi
                    fi
                done
                ;;
            5)
                while true; do
                    read -p "$(print_status "INPUT" "Enable GUI mode? (y/n, current: $GUI_MODE): ")" gui_in
                    if [[ -z "$gui_in" ]]; then break
                    elif [[ "$gui_in" =~ ^[Yy]$ ]]; then GUI_MODE=true; break
                    elif [[ "$gui_in" =~ ^[Nn]$ ]]; then GUI_MODE=false; break
                    else print_status "ERROR" "Enter y or n"; fi
                done
                ;;
            6)
                while true; do
                    read -p "$(print_status "INPUT" "Port forwards (current: ${PORT_FORWARDS:-None}): ")" pf_in
                    pf_in="${pf_in:-$PORT_FORWARDS}"
                    if validate_input "forwards" "$pf_in"; then PORT_FORWARDS="$pf_in"; break; fi
                done
                ;;
            7)
                while true; do
                    read -p "$(print_status "INPUT" "Memory in MB (current: $MEMORY): ")" new_val
                    new_val="${new_val:-$MEMORY}"
                    if validate_input "number" "$new_val"; then MEMORY="$new_val"; break; fi
                done
                ;;
            8)
                while true; do
                    read -p "$(print_status "INPUT" "vCPU count (current: $CPUS): ")" new_val
                    new_val="${new_val:-$CPUS}"
                    if validate_input "number" "$new_val"; then CPUS="$new_val"; break; fi
                done
                ;;
            9)
                while true; do
                    read -p "$(print_status "INPUT" "Disk size (current: $DISK_SIZE): ")" new_val
                    new_val="${new_val:-$DISK_SIZE}"
                    if validate_input "size" "$new_val"; then DISK_SIZE="$new_val"; break; fi
                done
                ;;
            10)
                select_ryzen_processor
                ;;
            0)
                save_vm_config
                return 0
                ;;
            *)
                print_status "ERROR" "Invalid selection"
                continue
                ;;
        esac

        if [[ "$edit_choice" =~ ^(1|2|3)$ ]]; then
            setup_vm_image
        fi
        save_vm_config
    done
}

resize_vm_disk() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        print_status "INFO" "Current disk size: $DISK_SIZE"
        while true; do
            read -p "$(print_status "INPUT" "Enter new disk size (e.g., 50G): ")" new_size
            if validate_input "size" "$new_size"; then
                if [[ "$new_size" == "$DISK_SIZE" ]]; then
                    print_status "INFO" "Disk size unchanged."
                    return 0
                fi

                local cur_num=${DISK_SIZE%[GgMm]}
                local new_num=${new_size%[GgMm]}
                local cur_unit=${DISK_SIZE: -1}
                local new_unit=${new_size: -1}

                [[ "$cur_unit" =~ [Gg] ]] && cur_num=$((cur_num * 1024))
                [[ "$new_unit" =~ [Gg] ]] && new_num=$((new_num * 1024))

                if [ "$new_num" -lt "$cur_num" ]; then
                    print_status "WARN" "Shrinking a disk image can corrupt guest filesystems!"
                    read -p "$(print_status "INPUT" "Proceed with shrink? (y/N): ")" -n 1 -r
                    echo
                    [[ ${REPLY:-} =~ ^[Yy]$ ]] || return 0
                fi

                if qemu-img resize "$IMG_FILE" "$new_size"; then
                    DISK_SIZE="$new_size"
                    save_vm_config
                    print_status "SUCCESS" "Resized '$vm_name' disk to $new_size."
                else
                    print_status "ERROR" "Failed to resize disk image."
                fi
                break
            fi
        done
    fi
}

show_vm_performance() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        echo
        print_status "INFO" "Performance & Resource Report: $vm_name"
        echo "=================================================="
        echo "Configured CPU : $CPU_LABEL ($CPU_MODEL)"
        echo "Allocation     : ${MEMORY} MB RAM | ${CPUS} vCPU | ${DISK_SIZE} Disk"
        echo "Accel Mode     : $KVM_STATUS_LABEL"
        if is_vm_running "$vm_name"; then
            local qemu_pid
            qemu_pid=$(pgrep -f "qemu-system-x86_64.*${IMG_FILE}" | head -n 1 || true)
            if [[ -n "$qemu_pid" ]]; then
                echo "QEMU PID       : $qemu_pid"
                ps -p "$qemu_pid" -o pid,%cpu,%mem,rss,vsz --no-headers || true
            fi
        else
            echo "Status         : Stopped"
        fi
        echo "Host Memory    :"
        free -h
        echo "=================================================="
    fi
}


# v8 management tools. They operate on one selected VM and preserve existing disks unless the user explicitly resizes/deletes them.
vm_terminal() {
    local vm_name="$1"
    if ! load_vm_config "$vm_name"; then return 1; fi
    if is_vm_running "$vm_name"; then
        print_status "INFO" "Connecting to '$vm_name' over its configured SSH forward."
        print_status "INFO" "If SSH is not ready yet, wait for guest boot and retry."
        command -v ssh >/dev/null 2>&1 || { print_status "ERROR" "OpenSSH client is missing."; return 1; }
        ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -p "$SSH_PORT" \
            "${USERNAME}@127.0.0.1" || print_status "WARN" "SSH session ended or connection failed. Check VM boot and SSH availability."
    else
        print_status "INFO" "VM is stopped. Starting it in the background before attempting SSH."
        start_vm "$vm_name" || return 1
        sleep 3
        if is_vm_running "$vm_name"; then
            ssh -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new -p "$SSH_PORT" "${USERNAME}@127.0.0.1" \
                || print_status WARN "VM is running, but SSH is not ready/reachable yet. Wait for cloud-init to finish and retry."
        fi
    fi
}

show_connection_details() {
    local vm_name="$1"
    if ! load_vm_config "$vm_name"; then return 1; fi
    local public_ip="not detected"
    if command -v curl >/dev/null 2>&1; then
        public_ip="$(curl -4 -fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"
    elif command -v wget >/dev/null 2>&1; then
        public_ip="$(wget -4 -qO- --timeout=4 https://api.ipify.org 2>/dev/null || true)"
    fi
    [[ -n "$public_ip" ]] || public_ip="not detected (offline/provider restriction)"
    echo
    printf "${C_VIOLET}╔════════════ MIRACLE CLOUD • TERMIUS CONNECTION ════════════╗${C_RESET}\n"
    printf " VM name       : %s\n" "$vm_name"
    printf " Host address  : %s\n" "$public_ip"
    printf " SSH host port : %s\n" "$SSH_PORT"
    printf " Guest user    : %s\n" "$USERNAME"
    printf " Local test    : ssh -p %s %s@127.0.0.1\n" "$SSH_PORT" "$USERNAME"
    printf "\n"
    printf " Termius fields:\n   Address: %s\n   Port: %s\n   Username: %s\n   Password: use the VM login password you set (not displayed)\n" "$public_ip" "$SSH_PORT" "$USERNAME"
    printf "\n"
    print_status "WARN" "Public-IP SSH only works if the provider/firewall permits inbound traffic and the host port is reachable."
    print_status "WARN" "This manager uses QEMU user-mode NAT by default; the guest normally does not receive its own public IPv4."
    echo
}

show_network_info() {
    local vm_name="$1"
    if ! load_vm_config "$vm_name"; then return 1; fi
    local public_ip="not detected"
    if command -v curl >/dev/null 2>&1; then
        public_ip="$(curl -4 -fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"
    elif command -v wget >/dev/null 2>&1; then
        public_ip="$(wget -4 -qO- --timeout=4 https://api.ipify.org 2>/dev/null || true)"
    fi
    [[ -n "$public_ip" ]] || public_ip="not detected"
    echo
    print_status "INFO" "IPv4 report for VM '$vm_name'"
    printf " Host public IPv4 : %s\n" "$public_ip"
    printf " Host interfaces:\n"
    if command -v ip >/dev/null 2>&1; then ip -4 -brief address show 2>/dev/null || true; else echo "  (ip command unavailable)"; fi
    printf " QEMU network     : user-mode NAT (10.0.2.0/24 is the usual guest subnet)\n"
    printf " SSH forward      : host TCP %s -> guest TCP 22\n" "$SSH_PORT"
    if [[ -n "${PORT_FORWARDS:-}" ]]; then printf " Extra forwards   : %s\n" "$PORT_FORWARDS"; else printf " Extra forwards   : none\n"; fi
    echo
    print_status "WARN" "Static guest IPv4 cannot be safely enabled by changing only the VM config while using user-mode NAT."
    print_status "INFO" "A provider-assigned static/public IPv4 generally requires provider routing plus bridged/TAP networking and firewall configuration."
    read -r -p "Show a safe checklist for static IPv4 setup? (y/N): " answer
    if [[ "${answer,,}" == y || "${answer,,}" == yes ]]; then
        cat <<'EOF'
Static IPv4 checklist (informational; no network settings were changed):
  1. Confirm the provider assigns an address, gateway, prefix/netmask and DNS.
  2. Confirm the VM host supports TAP/bridge networking and that policy allows it.
  3. Back up host network configuration and keep provider console access available.
  4. Configure the bridge/TAP and provider route/firewall first.
  5. Configure the guest's netplan/network-manager settings only after the upstream path works.
  6. Test a second session before closing your existing access.
Do not guess a gateway or configure an arbitrary public IP; that can lock you out.
EOF
    fi
    echo
}

sshx_vm_session() {
    local vm_name="$1"
    if ! load_vm_config "$vm_name"; then return 1; fi
    if ! is_vm_running "$vm_name"; then
        print_status "WARN" "VM is stopped. Start it first, then use SSHX."
        return 0
    fi
    command -v ssh >/dev/null 2>&1 || { print_status "ERROR" "OpenSSH client is missing."; return 1; }
    print_status "WARN" "SSHX creates a shareable terminal link. Anyone with the link may gain access to the shared session."
    read -r -p "Continue to the VM and check whether sshx is installed? (y/N): " answer
    [[ "${answer,,}" == y || "${answer,,}" == yes ]] || return 0
    ssh -t -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -p "$SSH_PORT" \
        "${USERNAME}@127.0.0.1" 'if command -v sshx >/dev/null 2>&1; then exec sshx; else echo "sshx is not installed in this VM."; echo "Review the official sshx installation instructions at https://sshx.io/ before installing."; exec "${SHELL:-/bin/bash}" -l; fi' \
        || print_status "WARN" "SSHX/SSH session ended or failed."
}

create_miracle_plus() {
    print_status INFO "MIRACLE+ Full Auto — hosting VM provisioning"
    print_status WARN "Requested defaults need 96 GiB RAM and a 1000G sparse virtual disk; confirm host capacity before continuing."
    local os_choice os_label
    echo " 1) Ubuntu 24.04 LTS"
    echo " 2) Ubuntu 22.04 LTS"
    echo " 3) Debian 12 (Bookworm)"
    echo " 4) Debian 11 (Bullseye)"
    read -r -p "Choose OS [1]: " os_choice; os_choice="${os_choice:-1}"
    case "$os_choice" in
      1) IFS='|' read -r OS_TYPE CODENAME IMG_URL _ DEFAULT_USERNAME _ <<< "${OS_OPTIONS["Ubuntu 24.04 LTS"]}" ;;
      2) IFS='|' read -r OS_TYPE CODENAME IMG_URL _ DEFAULT_USERNAME _ <<< "${OS_OPTIONS["Ubuntu 22.04 LTS"]}" ;;
      3) IFS='|' read -r OS_TYPE CODENAME IMG_URL _ DEFAULT_USERNAME _ <<< "${OS_OPTIONS["Debian 12 (Bookworm)"]}" ;;
      4) IFS='|' read -r OS_TYPE CODENAME IMG_URL _ DEFAULT_USERNAME _ <<< "${OS_OPTIONS["Debian 11 (Bullseye)"]}" ;;
      *) print_status ERROR "Invalid OS selection."; return 1 ;;
    esac
    VM_NAME="miraclecloud"
    if [[ -e "$VM_DIR/$VM_NAME.conf" || -e "$VM_DIR/$VM_NAME.img" ]]; then
        read -r -p "VM name miraclecloud already exists. Enter a different new VM name: " VM_NAME
        validate_input name "$VM_NAME" || return 1
        [[ ! -e "$VM_DIR/$VM_NAME.conf" && ! -e "$VM_DIR/$VM_NAME.img" ]] || { print_status ERROR "That VM name already exists; no files changed."; return 1; }
    fi
    HOSTNAME="miraclecloud"; USERNAME="root"; MIRACLE_PLUS=true; AUTOSTART=false
    read -r -s -p "Set a strong root password (not the insecure default 'root'): " PASSWORD; echo
    [[ -n "$PASSWORD" ]] || { print_status ERROR "Password cannot be empty."; return 1; }
    select_ryzen_processor || return 1
    read -r -p "Disk size [1000G]: " DISK_SIZE; DISK_SIZE="${DISK_SIZE:-1000G}"
    validate_input size "$DISK_SIZE" || return 1
    read -r -p "RAM in MiB [98304]: " MEMORY; MEMORY="${MEMORY:-98304}"
    validate_input number "$MEMORY" || return 1
    read -r -p "vCPU cores [8]: " CPUS; CPUS="${CPUS:-8}"
    validate_input number "$CPUS" || return 1
    read -r -p "Host SSH port forwarded to guest port 22 [2222]: " SSH_PORT; SSH_PORT="${SSH_PORT:-2222}"
    validate_input port "$SSH_PORT" || return 1
    if ss -tln 2>/dev/null | grep -Eq ":${SSH_PORT}[[:space:]]"; then print_status ERROR "Port $SSH_PORT is already listening."; return 1; fi
    read -r -p "Enable graphical mode/VNC? (y/N): " gui
    GUI_MODE=false; [[ "${gui,,}" == y || "${gui,,}" == yes ]] && GUI_MODE=true
    read -r -p "Additional host:guest TCP forwards (e.g. 25565:25565), blank for none: " PORT_FORWARDS
    validate_input forwards "$PORT_FORWARDS" || return 1
    IMG_FILE="$VM_DIR/$VM_NAME.img"; SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"; CREATED="$(date '+%Y-%m-%d %H:%M:%S')"; VNC_PASSWORD=""
    mkdir -p "$VM_DIR"
    local avail_kb host_mem_mb host_cpus
    avail_kb="$(df -Pk "$VM_DIR" | awk 'NR==2 {print $4}')"
    host_mem_mb="$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)"
    host_cpus="$(nproc 2>/dev/null || echo 1)"
    if [[ "$host_mem_mb" =~ ^[0-9]+$ ]] && (( host_mem_mb < MEMORY )); then
        print_status WARN "Host currently reports about ${host_mem_mb} MiB available RAM, below the requested ${MEMORY} MiB. Starting this VM may cause severe pressure or fail."
        read -r -p "Continue anyway? (y/N): " mem_cont
        [[ "${mem_cont,,}" == y || "${mem_cont,,}" == yes ]] || return 1
    fi
    if [[ "$host_cpus" =~ ^[0-9]+$ ]] && (( host_cpus < CPUS )); then
        print_status WARN "Host exposes $host_cpus logical CPUs; requested VM vCPU count is $CPUS. This may oversubscribe the host."
    fi
    if [[ "$DISK_SIZE" =~ ^([0-9]+)[Gg]$ ]] && (( avail_kb < ${BASH_REMATCH[1]} * 1024 * 1024 )); then
        print_status WARN "Available filesystem space is below the requested virtual disk capacity; qcow2 is sparse, but growth needs real free space."
        read -r -p "Continue with sparse disk after this warning? (y/N): " cont
        [[ "${cont,,}" == y || "${cont,,}" == yes ]] || return 1
    fi
    setup_vm_image || return 1
    save_vm_config || return 1
    print_status SUCCESS "Miracle+ VM created. It is not running yet; choose Start VM."
    print_status INFO "Cloud-init will attempt package updates and install Fastfetch, Neofetch when available, and common hosting utilities on first boot."
}

install_cloudflared() {
    command -v cloudflared >/dev/null 2>&1 && return 0
    print_status WARN "cloudflared is missing; attempting official Cloudflare .deb installation."
    [[ -r /etc/os-release ]] || { print_status ERROR "Cannot identify host OS for cloudflared installation."; return 1; }
    . /etc/os-release
    [[ "${ID:-}" == ubuntu || "${ID:-}" == debian || "${ID_LIKE:-}" == *debian* ]] || { print_status ERROR "Automatic install currently supports Debian/Ubuntu hosts only."; return 1; }
    command -v dpkg >/dev/null 2>&1 || { print_status ERROR "dpkg is unavailable."; return 1; }
    local arch url pkg
    case "$(dpkg --print-architecture)" in
      amd64) arch=amd64 ;; arm64) arch=arm64 ;; armhf) arch=arm ;; *) print_status ERROR "Unsupported host architecture."; return 1 ;;
    esac
    pkg="$(mktemp /tmp/cloudflared.XXXXXX.deb)"
    url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.deb"
    if ! wget -q --https-only "$url" -O "$pkg" || ! dpkg-deb --info "$pkg" >/dev/null 2>&1; then rm -f "$pkg"; print_status ERROR "Could not download/validate the official Cloudflare package."; return 1; fi
    if [[ "$(id -u)" -ne 0 ]]; then rm -f "$pkg"; print_status ERROR "Install requires root privileges."; return 1; fi
    if ! dpkg -i "$pkg"; then apt-get -f install -y || { rm -f "$pkg"; return 1; }; fi
    rm -f "$pkg"
    command -v cloudflared >/dev/null 2>&1
}

install_vnc_dependencies() {
    local missing=false
    command -v socat >/dev/null 2>&1 || missing=true
    command -v websockify >/dev/null 2>&1 || command -v novnc_proxy >/dev/null 2>&1 || missing=true
    [[ -d /usr/share/novnc ]] || command -v novnc_proxy >/dev/null 2>&1 || missing=true
    [[ "$missing" == false ]] && return 0
    [[ "$(id -u)" -eq 0 ]] || { print_status ERROR "Automatic noVNC/socat installation requires root on the host."; return 1; }
    [[ -r /etc/os-release ]] || { print_status ERROR "Cannot identify host OS for noVNC dependencies."; return 1; }
    . /etc/os-release
    [[ "${ID:-}" == ubuntu || "${ID:-}" == debian || "${ID_LIKE:-}" == *debian* ]] || { print_status ERROR "Automatic noVNC installation supports Debian/Ubuntu hosts only."; return 1; }
    print_status INFO "Installing host packages novnc, python3-websockify, and socat..."
    apt-get update && apt-get install -y novnc python3-websockify socat || { print_status ERROR "Could not install noVNC dependencies; no tunnel was started."; return 1; }
    command -v socat >/dev/null 2>&1 && { command -v websockify >/dev/null 2>&1 || command -v novnc_proxy >/dev/null 2>&1; }
}

vnc_quick_tunnel() {
    local vm_name="$1"
    load_vm_config "$vm_name" || return 1
    [[ "$GUI_MODE" == true ]] || { print_status ERROR "This VM was not created with GUI/VNC mode. Edit configuration or create a GUI-enabled VM first."; return 1; }
    is_vm_running "$vm_name" || { print_status ERROR "Start the VM before creating a VNC tunnel."; return 1; }
    [[ -S "$VM_DIR/$vm_name.monitor" ]] || { print_status ERROR "QEMU monitor socket is missing; restart the VM with v8 to enable authenticated VNC."; return 1; }
    install_vnc_dependencies || return 1
    install_cloudflared || return 1
    local vnc_pass="${VNC_PASSWORD:-}" monitor="$VM_DIR/$vm_name.monitor" web_port=6080 vnc_port=5901 vnc_display=1 vnc_pid="$VM_DIR/$vm_name.novnc.pid" tunnel_pid="$VM_DIR/$vm_name.tunnel.pid" log="$VM_DIR/$vm_name.tunnel.log"
    if [[ -r "$VM_DIR/$vm_name.vnc-display" ]]; then vnc_display="$(cat "$VM_DIR/$vm_name.vnc-display")"; fi
    vnc_port=$((5900+vnc_display))
    for web_port in {6080..6180}; do if ! ss -ltn 2>/dev/null | grep -Eq "127\.0\.0\.1:$web_port[[:space:]]"; then break; fi; done
    if (( web_port > 6180 )); then print_status ERROR "No free local web port for noVNC."; return 1; fi
    if [[ -r "$tunnel_pid" ]] && kill -0 "$(cat "$tunnel_pid")" 2>/dev/null; then
        print_status INFO "A tunnel process is already running; latest log: $log"
        grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$log" | tail -1 || true
        return 0
    fi
    if [[ -z "$vnc_pass" ]]; then
        read -r -s -p "Set a strong VNC password (exactly 8 alphanumeric characters for classic VNC auth): " vnc_pass; echo
        [[ "$vnc_pass" =~ ^[A-Za-z0-9]{8}$ ]] || { print_status ERROR "Use exactly 8 alphanumeric characters for classic QEMU VNC password authentication."; return 1; }
        VNC_PASSWORD="$vnc_pass"; save_vm_config
    fi
    [[ "$vnc_pass" =~ ^[A-Za-z0-9]{8}$ ]] || { print_status ERROR "Stored VNC password is invalid; reset it to exactly 8 alphanumeric characters."; return 1; }
    # Set password via QEMU monitor; keep VNC bound to loopback only.
    printf 'change vnc password %s\n' "$vnc_pass" | socat - "UNIX-CONNECT:$monitor" >/dev/null 2>&1 || { print_status ERROR "Could not set QEMU VNC password. No public tunnel was started."; return 1; }
    local novnc_cmd=()
    if command -v novnc_proxy >/dev/null 2>&1; then novnc_cmd=(novnc_proxy --listen "127.0.0.1:$web_port" --vnc "127.0.0.1:$vnc_port")
    else novnc_cmd=(websockify --web=/usr/share/novnc "127.0.0.1:$web_port" "127.0.0.1:$vnc_port"); fi
    nohup "${novnc_cmd[@]}" > "$VM_DIR/$vm_name.novnc.log" 2>&1 & echo $! > "$vnc_pid"
    sleep 1
    kill -0 "$(cat "$vnc_pid")" 2>/dev/null || { print_status ERROR "noVNC failed to start; inspect $VM_DIR/$vm_name.novnc.log"; rm -f "$vnc_pid"; return 1; }
    nohup cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:$web_port" > "$log" 2>&1 & echo $! > "$tunnel_pid"
    local url=""; for _ in {1..20}; do url="$(grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$log" 2>/dev/null | tail -1 || true)"; [[ -n "$url" ]] && break; kill -0 "$(cat "$tunnel_pid")" 2>/dev/null || break; sleep 1; done
    if [[ -z "$url" ]]; then print_status ERROR "Quick Tunnel URL was not detected. Inspect $log; stop the partial tunnel before retrying."; return 1; fi
    print_status SUCCESS "VNC Quick Tunnel is active: $url/vnc.html"
    print_status WARN "This URL is public. VNC password authentication is enabled; share the URL and password only with trusted people. Quick Tunnel URLs are temporary."
    print_status INFO "Tunnel log: $log | stop tunnel using menu option 14."
}

stop_vnc_tunnel() {
    local vm_name="$1"
    local stopped=false
    for suffix in tunnel novnc; do
        local pidfile="$VM_DIR/$vm_name.$suffix.pid"
        if [[ -r "$pidfile" ]]; then
            local pid; pid="$(cat "$pidfile" 2>/dev/null || true)"
            if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then pkill -TERM -P "$pid" 2>/dev/null || true; kill "$pid" 2>/dev/null || true; stopped=true; fi
            rm -f "$pidfile"
        fi
    done
    if [[ "$stopped" == true ]]; then print_status SUCCESS "VNC/Cloudflare tunnel processes stopped."; else print_status INFO "No tracked VNC tunnel processes were running."; fi
}

enable_vm_autostart() {
    local vm_name="$1"
    load_vm_config "$vm_name" || return 1
    command -v systemctl >/dev/null 2>&1 && [[ "$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')" == systemd ]] || { print_status ERROR "Boot autostart requires systemd on the host. This environment does not appear to run systemd."; return 1; }
    [[ "$(id -u)" -eq 0 ]] || { print_status ERROR "Creating a system service requires root. Run the manager with sudo/root."; return 1; }
    local script_path vm_dir unit="/etc/systemd/system/miracle-vm-${vm_name}.service"
    script_path="$(readlink -f "$0")"; vm_dir="$VM_DIR"
    cat > "$unit" <<EOF
[Unit]
Description=Miracle Cloud VM $vm_name
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment=VM_DIR=$vm_dir
ExecStart=$script_path --start-daemon $vm_name
ExecStop=$script_path --stop-daemon $vm_name
TimeoutStartSec=120
TimeoutStopSec=45

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$unit"
    if ! systemctl daemon-reload || ! systemctl enable "$unit"; then print_status ERROR "Could not enable systemd unit; review $unit"; return 1; fi
    AUTOSTART=true; save_vm_config
    print_status SUCCESS "Enabled boot autostart for $vm_name. This starts the VM at host boot; it cannot prevent provider shutdowns."
}

main_menu() {
    while true; do
        detect_kvm_support
        display_header

        local vms=()
        mapfile -t vms < <(get_vm_list)
        local vm_count=${#vms[@]}

        if [ "$vm_count" -gt 0 ]; then
            print_status "INFO" "Active & Saved Virtual Machines ($vm_count):"
            for i in "${!vms[@]}"; do
                local status="${C_GRAY}Stopped${C_RESET}"
                if is_vm_running "${vms[$i]}"; then
                    status="${C_GREEN}Running${C_RESET}"
                fi
                printf "  ${C_GOLD}%2d)${C_RESET} ${C_WHITE}%-22s${C_RESET} [%b]\n" "$((i+1))" "${vms[$i]}" "$status"
            done
            echo
        fi

        printf "${C_VIOLET}── COMMAND DECK ────────────────────────────────────────────────────────────────────${C_RESET}\n"
        echo "  1) Create a new VM (OS + CPU + Resources)"
        echo " 15) Create Miracle+ Full Auto (Debian/Ubuntu hosting VM)"
        if [ "$vm_count" -gt 0 ]; then
            echo "  2) Start a VM"
            echo "  3) Stop a VM"
            echo "  4) Show VM info"
            echo "  5) Edit VM configuration"
            echo "  6) Delete a VM"
            echo "  7) Resize VM disk"
            echo "  8) Show VM performance"
            echo "  9) Open VM terminal (start if stopped, then SSH)"
            echo " 10) Termius connection details"
            echo " 11) IPv4 / networking report + static-IP checklist"
            echo " 12) SSHX interactive shared terminal"
            echo " 13) Start VNC + Cloudflare Quick Tunnel"
            echo " 14) Stop VNC/Cloudflare tunnel"
            echo " 16) Enable VM autostart after host reboot (systemd)"
        fi
        echo "  0) Exit"
        echo

        read -p "$(print_status "INPUT" "Select action: ")" choice

        case "$choice" in
            1)
                create_new_vm
                ;;
            2|3|4|5|6|7|8|9|10|11|12|13|14|16)
                if [ "$vm_count" -lt 1 ]; then
                    print_status "ERROR" "No existing VMs available."
                else
                    read -p "$(print_status "INPUT" "Enter VM number (1-${vm_count}): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le "$vm_count" ]; then
                        local target_vm="${vms[$((vm_num-1))]}"
                        case "$choice" in
                            2) start_vm "$target_vm" ;;
                            3) stop_vm "$target_vm" ;;
                            4) show_vm_info "$target_vm" ;;
                            5) edit_vm_config "$target_vm" ;;
                            6) delete_vm "$target_vm" ;;
                            7) resize_vm_disk "$target_vm" ;;
                            8) show_vm_performance "$target_vm" ;;
                            9) vm_terminal "$target_vm" ;;
                            10) show_connection_details "$target_vm" ;;
                            11) show_network_info "$target_vm" ;;
                            12) sshx_vm_session "$target_vm" ;;
                            13) vnc_quick_tunnel "$target_vm" ;;
                            14) stop_vnc_tunnel "$target_vm" ;;
                            16) enable_vm_autostart "$target_vm" ;;
                        esac
                    else
                        print_status "ERROR" "Invalid VM number."
                    fi
                fi
                ;;
            15)
                create_miracle_plus
                ;;
            0)
                print_status "INFO" "Shutting down Miracle VM Manager. Goodbye!"
                exit 0
                ;;
            *)
                print_status "ERROR" "Invalid menu option."
                ;;
        esac

        read -p "$(print_status "INPUT" "Press Enter to return to control center...")"
    done
}

WORK_TMP_DIR="$(mktemp -d /tmp/miracle_vm.XXXXXX)"
trap cleanup EXIT

check_dependencies
detect_kvm_support

VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

declare -A CPU_OPTIONS=(
    ["Ryzen EPYC Genoa (Zen 4 Class)"]="EPYC-Genoa-v1|+ibpb,+virt-ssbd"
    ["Ryzen EPYC Milan (Zen 3 Class)"]="EPYC-Milan-v2|+ibpb,+virt-ssbd"
    ["Ryzen EPYC Rome (Zen 2 Class)"]="EPYC-Rome-v4|+ibpb,+virt-ssbd"
    ["Ryzen EPYC Classic (Zen 1 Class)"]="EPYC-v4|+ibpb,+virt-ssbd"
    ["AMD EPYC generic"]="EPYC|+ibpb,+virt-ssbd"
    ["Intel Xeon Skylake Server"]="Skylake-Server|"
    ["Intel Xeon Cascade Lake Server"]="Cascadelake-Server|"
    ["Intel Broadwell"]="Broadwell|"
    ["Intel Haswell"]="Haswell|"
    ["Generic x86-64 (portable)"]="qemu64|"
    ["Host passthrough (best host match; KVM only)"]="host|+virt-ssbd"
)

declare -A OS_OPTIONS=(
    ["Ubuntu 22.04 LTS"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04 LTS"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Debian 11 (Bullseye)"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12 (Bookworm)"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Fedora 40 Cloud"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

if [[ "${1:-}" == "--start-daemon" && -n "${2:-}" ]]; then
    load_vm_config "$2" || exit 1
    start_vm "$2"
    exit $?
elif [[ "${1:-}" == "--stop-daemon" && -n "${2:-}" ]]; then
    stop_vm "$2"
    exit $?
fi

startup_animation
main_menu
