MIRACLE CLOUD VM MANAGER v8.0 — ULTIMATE EDITION
================================================

Files
-----
manager.sh  Main VM manager and interactive menu.
editvm.sh   Separate safe configuration editor. It backs up a VM config before saving and never resizes/replaces disks.

Requirements
------------
- Bash 4+ (associative arrays are used)
- qemu-system-x86_64, qemu-img, cloud-localds (cloud-image-utils), wget, openssl
- Recommended host: Debian/Ubuntu with KVM and systemd; features vary by host/provider.
- Optional VNC tunnel dependencies are installed on demand: novnc, python3-websockify, socat, cloudflared.

Run
---
  chmod +x manager.sh editvm.sh
  ./manager.sh

Default VM directory is $HOME/vms. To use another directory:
  VM_DIR=/path/to/vms ./manager.sh

New in v8
---------
- Premium terminal theme and 3-second animated startup in interactive TTYs; animations are skipped in non-interactive use.
- Thirty requested retail CPU choices plus portable/host-passthrough choices. Retail labels map to QEMU CPU model aliases and are explicitly approximate; QEMU does not emulate each retail CPU's exact silicon, 3D V-Cache, or hybrid-core layout. Unsupported models fall back to a compatible model when detectable.
- Miracle+ Full Auto option (menu 15): choose Debian/Ubuntu; defaults to hostname/user `miraclecloud`/`root`, 1000G sparse qcow2 target, 98304 MiB RAM, 8 vCPUs; prompts for a non-default root password and optional networking/GUI settings. On first boot, cloud-init attempts OS updates, Fastfetch, Neofetch when available, and common hosting utilities.
- QEMU VMs start in the background with per-VM PID/log/serial/monitor files, so the manager menu remains usable.
- Option 12 retains SSHX/SSH terminal workflow. SSHX must be available inside the guest for a shareable SSHX session; if it is not installed, the script does not blindly execute an unverified remote installer.
- Options 13/14 start/stop a noVNC web proxy and Cloudflare Quick Tunnel for GUI-enabled VMs. Cloudflared and noVNC dependencies are installed on demand on Debian/Ubuntu hosts when run as root. VNC is bound to loopback and password authentication is configured.
- Option 16 creates a systemd unit to start a selected VM at host boot. Requires root, systemd, and a stable location for manager.sh. This does not prevent a provider from stopping the host.
- Safer disk resize handling: if qemu-img resize fails, the manager reports the failure and does not replace the existing disk with a blank image.
- Config writes use Bash `%q` quoting and restrictive file permissions; editor preserves v8 metadata fields.

Important limitations / security
--------------------------------
- A 1000G disk target is sparse and grows as data is written. It does not create physical storage; free host disk capacity must be monitored. 96 GiB RAM/8 vCPU must fit the actual host limits.
- QEMU CPU aliases depend on the installed QEMU version. Retail names are labels mapped to architecture-class aliases, not a claim that the host physically has that CPU.
- Cloudflare Quick Tunnel URLs are temporary/public. VNC password authentication is enabled, but share the URL and password only with trusted people. Stop the tunnel with option 14.
- VNC classic password authentication is limited to 8 characters; use a random, unique password. The manager stores it in the VM config, which is chmod 600.
- VM login passwords are stored in mode-600 config files for compatibility with the current cloud-init workflow. Protect the VM directory and backups. Avoid weak passwords and never reuse them.
- Option 16 uses systemd on the host and will refuse unsupported container environments. KVM, networking, static public IPv4, and nested virtualization depend on the hosting provider.
- Existing v7 VM images and config files are not automatically deleted or reformatted. Back up the VM directory before a major upgrade. Do not run two managers against the same VM at the same time.
- Syntax/static checks are not equivalent to a live QEMU/KVM test. This build environment does not include QEMU, cloud-localds, or qemu-img, so VM boot, cloud-init, VNC, and systemd autostart could not be live-tested here.

Upgrade guidance
----------------
1. Stop existing VMs cleanly before replacing scripts.
2. Back up the complete VM directory, including *.conf, *.img, and *-seed.iso.
3. Keep the v8 scripts in a stable path if enabling systemd autostart.
4. Start with a small test VM before creating the 96-GiB Miracle+ VM.
