
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
            echo "  9) Open VM terminal (SSH if running; QEMU console if stopped)"
            echo " 10) Termius connection details"
            echo " 11) IPv4 / networking report + static-IP checklist"
            echo " 12) SSHX shared terminal session"
        fi
        echo "  0) Exit"
        echo

        read -p "$(print_status "INPUT" "Select action: ")" choice

        case "$choice" in
            1)
                create_new_vm
                ;;
            2|3|4|5|6|7|8|9|10|11|12)
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

main_menu
