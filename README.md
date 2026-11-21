






☁️ Miracle Cloud VM
<p align="center"> <strong>Premium QEMU virtual-machine management for Linux</strong><br> Create, inspect, start, stop, and reconfigure VMs from a terminal interface. </p><p align="center"> <img src="https://img.shields.io/badge/PROJECT-MIRACLE%20CLOUD-7C3AED?style=for-the-badge" alt="Miracle Cloud VM"> <img src="https://img.shields.io/badge/PLATFORM-Ubuntu%20%7C%20Debian-111827?style=for-the-badge&logo=linux&logoColor=white" alt="Ubuntu and Debian"> <img src="https://img.shields.io/badge/ENGINE-QEMU%20%2F%20KVM-DC2626?style=for-the-badge" alt="QEMU and KVM"> </p><p align="center"> <a href="#-quick-install">Quick install</a> · <a href="#-preview">Preview</a> · <a href="#-usage">Usage</a> · <a href="#-editing-and-reinstalling-a-vm">Edit a VM</a> · <a href="#-troubleshooting">Troubleshooting</a> </p>
Miracle Cloud VM is a Bash-based virtual-machine management project built around QEMU and cloud-init. manager.sh is the main interactive manager. editvm.sh is a separate editor that can rebuild an existing VM from the cloud image configured for that VM.

[!CAUTION]
Rebuilding a VM installs a fresh guest disk. Applications, settings, and files on the old guest disk will not appear on the new disk. Keep a separate backup of anything important and test the workflow on a disposable VM first.

✨ Features
The current manager.sh menu includes these operations:

Create a VM using one of the configured cloud-image options.
Start and stop a VM.
View the VM configuration and resource allocation.
Edit configuration values.
Delete a VM and its associated files after confirmation.
Resize a virtual disk.
View a basic performance and host-memory report.
The separate editvm.sh editor can request changes to the following fields before rebuilding the guest OS:

VM hostname and guest username
Login password
RAM allocation (MB) and virtual CPU count
QEMU CPU model/profile
Virtual disk size (the editor blocks shrinking the disk)
SSH host port and additional host-to-guest port forwards
GUI-mode preference
Exact options depend on the installed script version, QEMU capabilities, the selected cloud image, and the host environment. A CPU profile changes the CPU model presented to the guest; it does not change the physical processor in the host.

🖥️ Preview
This is a representative preview, not a screenshot. The real manager displays terminal colors, host information, and menu options based on the current VM list.

╔══════════════════════════════════════════════════════════════════════╗
║                    ⚡ MIRACLE VM MANAGER ⚡                           ║
║               QEMU / KVM Virtualization Console                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  1) Create a new VM                                                   ║
║  2) Start a VM                                                       ║
║  3) Stop a VM                                                        ║
║  4) Show VM info                                                     ║
║  5) Edit VM configuration                                            ║
║  6) Delete a VM                                                      ║
║  7) Resize VM disk                                                   ║
║  8) Show VM performance                                              ║
║  0) Exit                                                             ║
╚══════════════════════════════════════════════════════════════════════╝
To show a real preview image, capture a screenshot of the manager on a test host, add it to assets/miracle-cloud-vm.png, then use:

![Miracle Cloud VM preview](assets/miracle-cloud-vm.png)
🧩 Requirements
Ubuntu or Debian with apt.
Bash and root privileges (or sudo).
QEMU x86 system emulator and qemu-img.
cloud-localds from cloud-image-utils.
wget, curl, openssl, and standard Linux utilities.
Free storage for the downloaded image, replacement disk, and backups.
A compatible cloud image that supports cloud-init.
KVM hardware acceleration is optional. If /dev/kvm is unavailable, the manager attempts to use QEMU's software-emulation mode, which can be much slower. Host CPU passthrough requires KVM and may not work inside a container or VPS that does not expose virtualization.

🚀 Quick install
The following command installs common dependencies, downloads both scripts to /usr/local/bin, checks their Bash syntax, and installs them with executable permissions. It does not create a VM or guarantee that the server supports KVM.

Copy-and-run installer:

sudo apt update && \
sudo apt install -y qemu-system-x86 qemu-utils cloud-image-utils curl wget openssl ca-certificates ncurses-bin coreutils util-linux procps iproute2 grep sed gawk findutils && \
curl -fsSL --retry 3 https://raw.githubusercontent.com/cryzenn244-png/Miracle-Cloud-Vm/main/manager.sh -o /tmp/miracle-vm.manager.sh && \
bash -n /tmp/miracle-vm.manager.sh && \
curl -fsSL --retry 3 https://raw.githubusercontent.com/cryzenn244-png/Miracle-Cloud-Vm/main/editvm.sh -o /tmp/miracle-vm.editvm.sh && \
bash -n /tmp/miracle-vm.editvm.sh && \
sudo install -m 0755 /tmp/miracle-vm.manager.sh /usr/local/bin/miracle-vm && \
sudo install -m 0755 /tmp/miracle-vm.editvm.sh /usr/local/bin/editvm.sh && \
rm -f /tmp/miracle-vm.manager.sh /tmp/miracle-vm.editvm.sh && \
echo 'Miracle Cloud VM installed successfully.'
If the command stops with an error, read the last error message before retrying. Syntax validation only checks Bash parsing; it is not a full VM creation or rebuild test.

Launch the manager
sudo /usr/local/bin/miracle-vm
Launch the separate VM editor
sudo /usr/local/bin/editvm.sh
📦 Manual installation
Clone the repository:

git clone https://github.com/cryzenn244-png/Miracle-Cloud-Vm.git
cd Miracle-Cloud-Vm
Install the dependencies:

sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils cloud-image-utils curl wget openssl ca-certificates ncurses-bin coreutils util-linux procps iproute2 grep sed gawk findutils
Check both scripts before running them:

bash -n manager.sh
bash -n editvm.sh
Install them into your command path:

sudo install -m 0755 manager.sh /usr/local/bin/miracle-vm
sudo install -m 0755 editvm.sh /usr/local/bin/editvm.sh
🧭 Usage
Launch the manager with sudo /usr/local/bin/miracle-vm.
Choose Create a new VM and follow the prompts.
Set a VM name, guest hostname, username/password, disk size, RAM, vCPU count, SSH port, and optional port forwards.
Choose a configured OS image and CPU profile.
Use the menu to start the VM, stop it, inspect its configuration, resize its disk, or view its performance information.
The OS list and image URLs are defined in manager.sh and can change. Some old distribution image URLs may stop working; verify the image source if a download fails. Do not assume that every image supports all cloud-init features.

Connect to a guest over SSH
The manager configures the selected SSH host port to forward to port 22 in the guest. After the VM has booted and cloud-init has completed, use the actual username and port you configured:

ssh -p 2222 ubuntu@127.0.0.1
In this example, 2222 and ubuntu are examples only. Replace them with the VM's configured host port and guest username. If the VM runs on a remote server, run SSH from your own computer using that server's reachable address instead of 127.0.0.1, and ensure firewall rules allow the port.

🧰 Editing and reinstalling a VM
editvm.sh is designed to work with VM configuration files generated by the compatible manager.sh version. It expects the config, disk, and cloud-init seed to use the manager's naming convention.

1. Stop the VM
Use the manager to stop the selected VM cleanly before starting the editor. The editor also tries to detect a QEMU process using the disk, but you should verify the VM is stopped yourself.

2. Confirm the VM directory
The manager uses $HOME/vms unless VM_DIR is set. When the manager is run with sudo, that path is commonly /root/vms. To make the directory explicit, pass the same VM_DIR to both commands:

sudo env VM_DIR=/root/vms /usr/local/bin/miracle-vm
In a separate terminal session, launch the editor with that same directory:

sudo env VM_DIR=/root/vms /usr/local/bin/editvm.sh
Replace /root/vms with the actual VM directory on your server. It must contain the manager-generated .conf files, along with each VM's disk and seed files.

3. Review and edit settings
Select the VM number displayed by the editor. Enter new values when prompted, or press Enter to keep the current value where supported.

Setting	Example	Notes
Hostname	mc-node-01	Letters, digits, _, and -; up to 63 characters
Username	ubuntu	Must follow the script's lowercase username format
RAM	4096	Positive integer in MB (4 GiB is 4096 MB)
vCPU cores	4	Positive integer; ensure the host has enough capacity
Disk	30G	Sizes such as 30G or 512M; shrinking is rejected
CPU profile	1–`5`	Choose from the profiles printed by the editor
SSH host port	2222	Must be within the accepted port range and available on the host
Port forwards	25565:25565,8080:80	Comma-separated host:guest pairs
GUI mode	y or n	Depends on the host and installed display support
Password	hidden prompt	Type a new password, or leave blank to keep the existing password
The editor validates input format, but it does not fully reserve host RAM, CPU, disk space, or network ports. Check available host resources before assigning them to the VM.

4. Confirm the rebuild
Read the planned configuration carefully. To proceed, type the exact word REINSTALL. Any other response cancels the operation.

The editor downloads the configured cloud image, converts it to QCOW2, resizes the new disk, creates a cloud-init seed ISO, and makes timestamped backups before replacing the disk and configuration where possible. Large VMs may require substantial free storage for the new disk and backup copies.

5. Boot and verify
Start the VM from the main manager and allow cloud-init time to finish. Verify the hostname, login, SSH access, ports, networking, and guest disk size. Keep the old disk and backups until you have verified that the rebuilt VM is usable.

[!WARNING]
A rebuild is destructive to the guest's installed OS and data. A timestamped backup is a fallback, not a guarantee of successful recovery. Make an independent backup first.

📁 Files and configuration
The editor expects this general layout inside the configured VM directory:

vms/
├── VM_NAME.conf        # VM configuration generated by manager.sh
├── VM_NAME.img         # Virtual disk image
└── VM_NAME-seed.iso    # Cloud-init seed image
The .conf file needs a valid, reachable IMG_URL and the configuration values used by the manager/editor. Only use configuration files you trust: the editor sources the selected config as a shell file, so a modified config could execute commands with the editor's privileges.

🔍 Verify the host
Check that QEMU and cloud-init tooling are installed:

qemu-system-x86_64 --version
qemu-img --version
cloud-localds --help
Check whether virtualization flags and KVM are exposed:

grep -Eoc 'vmx|svm' /proc/cpuinfo
ls -l /dev/kvm 2>/dev/null || true
A non-zero CPU flag count does not guarantee /dev/kvm access. Your provider or outer hypervisor may need to enable nested virtualization.

🧯 Troubleshooting
<details> <summary><strong>The copy button or code box does not appear</strong></summary>
Use the normal repository page where GitHub renders README.md, not the Raw file view. The fenced code blocks below are standard Markdown; GitHub provides its own copy control for rendered code blocks when available. A Markdown file cannot force GitHub's interface to show a custom clipboard button.

</details><details> <summary><strong>Missing QEMU or cloud-init command</strong></summary>
Install the packages and retry:

sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils cloud-image-utils
Then check:

command -v qemu-system-x86_64 qemu-img cloud-localds wget openssl
</details><details> <summary><strong>No VM configuration files found</strong></summary>
Pass the actual directory containing your VM .conf files:

sudo env VM_DIR=/actual/path/to/vms /usr/local/bin/editvm.sh
Do not use the example path literally; substitute the real directory from your setup.

</details><details> <summary><strong>Image download fails or IMG_URL is empty</strong></summary>
Inspect the selected VM's .conf file and verify that IMG_URL points to a trusted, reachable, cloud-init-compatible image. The editor cannot rebuild the VM without a valid source image.

</details><details> <summary><strong>Host CPU passthrough or KVM does not work</strong></summary>
Use a CPU profile supported by your QEMU version and host. Host passthrough requires KVM access. If /dev/kvm is unavailable, QEMU may use slower software emulation instead.

</details><details> <summary><strong>Guest password or hostname was not applied</strong></summary>
Allow the guest's first boot to complete and check the VM console. The selected image must support cloud-init and honor the supplied user-data. Generic images may behave differently.

</details><details> <summary><strong>Rebuild fails or disk space is low</strong></summary>
Check free disk space:

df -h
Keep the original disk and timestamped backups until the cause is understood. Do not delete backups to free space unless you have confirmed they are no longer needed.

</details>
🔐 Security recommendations
Inspect shell scripts before running them with root privileges.
Use trusted, up-to-date cloud images.
Use strong guest passwords and restrict access to VM configuration files.
Limit forwarded ports with firewall rules; expose only the services you intend to make reachable.
Protect backup disks because they may contain private files and credentials.
Test restore procedures and keep independent backups.
🧪 Validation
Before submitting changes, run these checks from the repository directory:

bash -n manager.sh
bash -n editvm.sh
A successful syntax check confirms Bash can parse the files; it does not prove that VM creation, boot, networking, or reinstallation succeeds on every host. Test those workflows on disposable VMs before production use.

🤝 Contributing
Fork the repository and create a feature branch.
Make focused changes and document configuration changes.
Run the syntax checks and test on a non-production host.
Open a pull request with the test environment, steps, and results.
📄 License
Add a LICENSE file if you intend to distribute the project. Until a license is included, do not assume others have permission to redistribute or relicense the code.

<p align="center"> <strong>Miracle Cloud VM</strong><br> <sub>Virtual machine management, with safety and transparency in mind.</sub> </p>




