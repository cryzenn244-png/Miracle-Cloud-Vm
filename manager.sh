#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                        MIRACLE VM MANAGER v6.0                               ║
# ║              Premium Ryzen & Multi-VM Virtualization Control                 ║
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
    printf "${C_VIOLET}║${C_GOLD}                        ⚡ MIRACLE VM MANAGER v6.0 ⚡                                ${C_VIOLET}║${C_RESET}\n"
    printf "${C_VIOLET}║${C_GRAY}              Ryzen-Class & Multi-OS QEMU/KVM Virtualization Suite                 ${C_VIOLET}║${C_RESET}\n"
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
    tput cnorm 2>/dev/null || true
    if [[ -n "${WORK_TMP_DIR:-}" && -d "$WORK_TMP_DIR" ]]; then
        rm -rf "$WORK_TMP_DIR"
    fi
    rm -f "user-data" "meta-data" 2>/dev/null || true
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
        unset CPU_LABEL CPU_MODEL CPU_FLAGS IMG_FILE SEED_FILE CREATED

        # shellcheck disable=SC1090
        source "$config_file"
        CPU_LABEL="${CPU_LABEL:-Ryzen EPYC Genoa (Zen 4 Class)}"
        CPU_MODEL="${CPU_MODEL:-EPYC-Genoa-v1}"
        CPU_FLAGS="${CPU_FLAGS:-+ibpb,+virt-ssbd}"
        return 0
    else
        print_status "ERROR" "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"

    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
CPU_LABEL="$CPU_LABEL"
CPU_MODEL="$CPU_MODEL"
CPU_FLAGS="$CPU_FLAGS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF

    print_status "SUCCESS" "Saved configuration to $config_file"
}

select_ryzen_processor() {
    print_status "INFO" "Select VPS Processor Profile (Ryzen / EPYC Architecture):"
    local keys=()
    local idx=1
    for k in "${!CPU_OPTIONS[@]}"; do
        keys[$idx]="$k"
        printf "  ${C_GOLD}%2d)${C_RESET} ${C_WHITE}%s${C_RESET}\n" "$idx" "$k"
        ((idx++))
    done

    while true; do
        read -p "$(print_status "INPUT" "Choose processor profile (1-${#CPU_OPTIONS[@]}, default 1): ")" cpu_choice
        cpu_choice="${cpu_choice:-1}"
        if [[ "$cpu_choice" =~ ^[0-9]+$ ]] && [ "$cpu_choice" -ge 1 ] && [ "$cpu_choice" -le ${#CPU_OPTIONS[@]} ]; then
            local chosen_key="${keys[$cpu_choice]}"
            IFS='|' read -r CPU_MODEL CPU_FLAGS <<< "${CPU_OPTIONS[$chosen_key]}"
            CPU_LABEL="$chosen_key"
            print_status "SUCCESS" "Processor selected: $CPU_LABEL ($CPU_MODEL)"
            break
        else
            print_status "ERROR" "Invalid processor selection. Enter 1-${#CPU_OPTIONS[@]}."
        fi
    done
}

build_cpu_arg() {
    local model="$1"
    local flags="$2"

    if [[ "$KVM_AVAILABLE" == true ]]; then
        if [[ "$model" == "host" ]]; then
            if [[ -n "$flags" ]]; then
                printf "host,%s" "$flags"
            else
                printf "host"
            fi
        else
            if [[ -n "$flags" ]]; then
                printf "%s,%s" "$model" "$flags"
            else
                printf "%s" "$model"
            fi
        fi
    else
        # Non-KVM (TCG) safe fallback so guests don't abort on unsupported host/AVX512/SEV flags
        case "$model" in
            host|EPYC-Genoa-v1|EPYC-v4)
                printf "EPYC-Rome-v2"
                ;;
            EPYC-Milan-v2|EPYC-Rome-v4)
                printf "EPYC-v1"
                ;;
            *)
                printf "qemu64"
                ;;
        esac
    fi
}

create_new_vm() {
    print_status "INFO" "Launching Miracle VM Creation Wizard..."

    print_status "INFO" "Select an Operating System:"
    local os_keys=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        os_keys[$i]="$os"
        printf "  ${C_GOLD}%2d)${C_RESET} ${C_WHITE}%s${C_RESET}\n" "$i" "$os"
        ((i++))
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
        read -s -p "$(print_status "INPUT" "Enter password (default: $DEFAULT_PASSWORD): ")" PASSWORD
        PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
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

    setup_vm_image
    save_vm_config
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
        print_status "WARN" "In-place resize failed; creating fresh qcow2 image at $DISK_SIZE..."
        qemu-img create -f qcow2 "${IMG_FILE}.new" "$DISK_SIZE"
        mv "${IMG_FILE}.new" "$IMG_FILE"
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
    print_status "INFO" "SSH Access: ssh -p $SSH_PORT $USERNAME@localhost (Password: $PASSWORD)"

    local qemu_cmd=(
        qemu-system-x86_64
        -name "$vm_name"
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
            ((net_idx++))
        done
    fi

    if [[ "$GUI_MODE" == true ]]; then
        qemu_cmd+=(-vga virtio -display gtk,gl=on)
    else
        qemu_cmd+=(-nographic -serial mon:stdio)
    fi

    qemu_cmd+=(
        -device virtio-balloon-pci
        -object "rng-random,filename=/dev/urandom,id=rng0"
        -device "virtio-rng-pci,rng=rng0"
    )

    "${qemu_cmd[@]}" || true
    print_status "INFO" "VM '$vm_name' session ended."
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
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}Password       ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$PASSWORD"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}SSH Port       ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$SSH_PORT"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}Resources      ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "${MEMORY} MB RAM • ${CPUS} vCPU • ${DISK_SIZE} Disk"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}GUI / Forwards ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "GUI=$GUI_MODE • Ports=${PORT_FORWARDS:-None}"
        printf "${C_VIOLET}║${C_RESET} ${C_CYAN}Created        ${C_RESET}: %-62s ${C_VIOLET}║${C_RESET}\n" "$CREATED"
        printf "${C_VIOLET}╚════════════════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
    fi
}

is_vm_running() {
    local vm_name=$1
    local img_path="$VM_DIR/$vm_name.img"
    if pgrep -f "qemu-system-x86_64.*${img_path}" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

stop_vm() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "INFO" "Stopping VM '$vm_name'..."
            pkill -f "qemu-system-x86_64.*${IMG_FILE}" >/dev/null 2>&1 || true
            sleep 2
            if is_vm_running "$vm_name"; then
                print_status "WARN" "Graceful stop timed out; forcing termination..."
                pkill -9 -f "qemu-system-x86_64.*${IMG_FILE}" >/dev/null 2>&1 || true
            fi
            print_status "SUCCESS" "VM '$vm_name' stopped."
        else
            print_status "INFO" "VM '$vm_name' is not running."
        fi
    fi
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
        echo "  1) Create a new VM (OS + Ryzen CPU + Resources)"
        if [ "$vm_count" -gt 0 ]; then
            echo "  2) Start a VM"
            echo "  3) Stop a VM"
            echo "  4) Show VM info"
            echo "  5) Edit VM configuration"
            echo "  6) Delete a VM"
            echo "  7) Resize VM disk"
            echo "  8) Show VM performance"
        fi
        echo "  0) Exit"
        echo

        read -p "$(print_status "INPUT" "Select action: ")" choice

        case "$choice" in
            1)
                create_new_vm
                ;;
            2|3|4|5|6|7|8)
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
                        esac
                    else
                        print_status "ERROR" "Invalid VM number."
                    fi
                fi
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
    ["Ryzen Host Passthrough (Native KVM)"]="host|+virt-ssbd"
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

main_menu
