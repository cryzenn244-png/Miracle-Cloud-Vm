# ☁️ Miracle Cloud VM

<p align="center">
  <img src="https://img.shields.io/badge/MIRACLE-CLOUD%20VM-8B5CF6?style=for-the-badge&logo=linux&logoColor=white" alt="Miracle Cloud VM"/>
  <img src="https://img.shields.io/badge/PLATFORM-LINUX-111827?style=for-the-badge&logo=linux&logoColor=white" alt="Linux"/>
  <img src="https://img.shields.io/badge/POWERED%20BY-QEMU-DC2626?style=for-the-badge" alt="QEMU"/>
</p>

<p align="center">
  <strong>A streamlined command-line virtual machine management tool.</strong>
  <br/>
  Manage your virtual machine workflow from a single terminal interface.
</p>

<p align="center">
  <a href="#-quick-install">Quick Install</a> ·
  <a href="#-preview">Preview</a> ·
  <a href="#-installation-tutorial">Tutorial</a> ·
  <a href="#-troubleshooting">Troubleshooting</a>
</p>

---

## ✨ Overview

**Miracle Cloud VM** is a QEMU-based VM management project designed to simplify virtual machine administration on compatible Linux servers.

The project provides a command-line entry point through `manager.sh`. Its actual VM creation, configuration, networking, and storage capabilities depend on the implementation of the manager script.

### Highlights

- ☁️ **Miracle Cloud identity** — a dedicated VM management project.
- 🖥️ **QEMU integration** — uses QEMU system emulation components.
- 💾 **Virtual disk utilities** — supports the QEMU disk-image toolchain.
- 📦 **Dependency installation** — install common packages through APT.
- ⚡ **Quick launch** — access the manager from a single command.
- 🛠️ **Linux administration** — intended for compatible Linux environments.
- 🔧 **Command-line workflow** — manage supported operations from the terminal.

> [!IMPORTANT]
> This repository provides a VM management script, not a complete cloud platform by itself. Verify that each feature is implemented in `manager.sh` before relying on it.

## 🖥️ Preview

The following is an **illustrative terminal mockup**, not a screenshot of the actual program.

```text
╭──────────────────────────────────────────────────────────╮
│                                                          │
│     ███╗   ███╗██╗██████╗  █████╗  ██████╗██╗     ███████╗│
│     ████╗ ████║██║██╔══██╗██╔══██╗██╔════╝██║     ██╔════╝│
│     ██╔████╔██║██║██████╔╝███████║██║     ██║     █████╗  │
│     ██║╚██╔╝██║██║██╔══██╗██╔══██║██║     ██║     ██╔══╝  │
│     ██║ ╚═╝ ██║██║██║  ██║██║  ██║╚██████╗███████╗███████╗│
│                                                          │
│                     CLOUD VM                             │
│              Virtual Machine Manager                     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  [1]  Create VM             [2]  List VMs                │
│  [3]  Start VM              [4]  Stop VM                 │
│  [5]  VM Information        [6]  Delete VM               │
│  [0]  Exit                                               │
│                                                          │
│  Status: Example interface only                          │
╰──────────────────────────────────────────────────────────╯
```

The menu above demonstrates a possible interface design. Available options may differ from the actual script.

## 🚀 Quick Install

### One-command installation

Run this command on a compatible Ubuntu or Debian server:

```bash
sudo apt update && \
sudo apt install -y qemu-system-x86 qemu-utils cloud-image-utils wget curl openssl ncurses-bin ca-certificates coreutils util-linux procps iproute2 sudo && \
sudo wget -qO /usr/local/bin/miracle-vm https://raw.githubusercontent.com/cryzenn244-png/Miracle-Cloud-Vm/main/manager.sh && \
sudo chmod 755 /usr/local/bin/miracle-vm && \
sudo /usr/local/bin/miracle-vm
```

This command installs common dependencies, downloads the manager, sets its executable permissions, and launches it.

### Launch later

Once installed, start the manager with:

```bash
sudo miracle-vm
```

> [!WARNING]
> The installer downloads and executes a remote shell script with elevated privileges. Review the source before running it on a production server. The command installs packages but does not guarantee that hardware virtualization is available.

## 📚 Installation Tutorial

### Step 1 — Connect to your server

Connect to your Ubuntu or Debian server using your usual SSH client, or open its terminal.

### Step 2 — Check your operating system

```bash
cat /etc/os-release
```

Confirm that your distribution uses APT before following the installation command.

### Step 3 — Install the required packages

```bash
sudo apt update
sudo apt install -y \
  qemu-system-x86 \
  qemu-utils \
  cloud-image-utils \
  wget \
  curl \
  openssl \
  ncurses-bin \
  ca-certificates \
  coreutils \
  util-linux \
  procps \
  iproute2
```

### Step 4 — Download Miracle Cloud VM

```bash
sudo wget -qO /usr/local/bin/miracle-vm \
  https://raw.githubusercontent.com/cryzenn244-png/Miracle-Cloud-Vm/main/manager.sh
```

### Step 5 — Set permissions

```bash
sudo chmod 755 /usr/local/bin/miracle-vm
```

### Step 6 — Launch the manager

```bash
sudo /usr/local/bin/miracle-vm
```

Follow the prompts provided by the actual program.

## 🔍 Verify Your Environment

Check whether QEMU is installed:

```bash
qemu-system-x86_64 --version
qemu-img --version
```

Check for CPU virtualization flags:

```bash
grep -Eoc 'vmx|svm' /proc/cpuinfo
```

A positive count indicates that virtualization flags are exposed to the operating system. It does not, by itself, guarantee that nested virtualization or VM creation will work.

If you are running inside another VM or container, your provider may need to enable nested virtualization or expose the necessary device access.

## 🧰 Troubleshooting

<details>
<summary><strong>QEMU command not found</strong></summary>

Install the required QEMU packages:

```bash
sudo apt install -y qemu-system-x86 qemu-utils
```

</details>

<details>
<summary><strong>Permission denied</strong></summary>

Check the executable permissions:

```bash
ls -l /usr/local/bin/miracle-vm
```

Launch the manager with appropriate permissions:

```bash
sudo miracle-vm
```

</details>

<details>
<summary><strong>Virtualization is unavailable</strong></summary>

Check whether your environment exposes CPU virtualization flags:

```bash
grep -Eoc 'vmx|svm' /proc/cpuinfo
```

Contact your VPS provider if hardware virtualization or nested virtualization is not available. Installing QEMU cannot enable a capability that the host does not expose.

</details>

<details>
<summary><strong>Download failed</strong></summary>

Check connectivity and confirm that the script exists at the configured repository URL:

```bash
curl -fIL https://raw.githubusercontent.com/cryzenn244-png/Miracle-Cloud-Vm/main/manager.sh
```

</details>

## 🔐 Security Notes

- Review shell scripts before running them as root.
- Keep your server and installed packages updated.
- Use trusted operating system images.
- Protect SSH access and server credentials.
- Understand the consequences of deleting virtual disks or VM data before confirming destructive operations.
- Do not expose VM management interfaces to the public internet without appropriate authentication and network restrictions.

## 🗺️ Project Roadmap

The following are potential improvements, not claims about currently implemented features.

- [ ] VM creation and lifecycle management
- [ ] Virtual disk and image management
- [ ] VM resource configuration
- [ ] Network configuration
- [ ] Resource usage reporting
- [ ] Input validation and error handling
- [ ] Backup and recovery workflow
- [ ] Automated installation checks
- [ ] Improved terminal interface

## 🤝 Contributing

Contributions, bug reports, and suggestions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Test your changes in a safe environment.
4. Submit a pull request describing the changes.

## ⚖️ Disclaimer

Miracle Cloud VM is provided as-is. Compatibility depends on the host operating system, available virtualization capabilities, permissions, and the functionality implemented in the manager script.

Always back up important data before modifying virtual machines or their storage.

## 📄 License

A license has not been specified here. Check the repository's existing license file before redistributing or modifying this project.

---

<p align="center">
  <strong>Miracle Cloud VM</strong>
  <br/>
  <sub>Built for streamlined Linux VM management.</sub>
</p>
