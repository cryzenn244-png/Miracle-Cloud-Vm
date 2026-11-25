## ⚡ Quick Install

Run the following command on your Linux VPS:

```bash
curl -fL --retry 3 \
  https://github.com/cryzenn244-png/Miracle-Cloud-Vm/archive/refs/heads/main.tar.gz \
  -o miracle-cloud-vm.tar.gz \
&& mkdir -p miracle-cloud-vm \
&& tar -xzf miracle-cloud-vm.tar.gz \
  --strip-components=1 -C miracle-cloud-vm \
&& cd miracle-cloud-vm \
&& chmod +x manager.sh editvm.sh \
&& ./manager.sh
```

**Requirements:** Linux, Bash, `curl`, `tar`, and the project files in the repository's `main` branch.

### 📋 Installation steps

1. Connect to your Linux VPS through SSH.
2. Ensure the required utilities are installed.
3. Paste the Quick Install command into your terminal.
4. Wait for the archive to download and extract.
5. The Miracle Cloud VM Manager interface will launch.

### 🔧 Manual installation

```bash
git clone https://github.com/cryzenn244-png/Miracle-Cloud-Vm.git
cd Miracle-Cloud-Vm
chmod +x manager.sh editvm.sh
./manager.sh
```

### ⚠️ Important

- Review the scripts before running them with elevated privileges.
- QEMU/KVM and additional dependencies may be required for VM operations.
- Back up existing VM configurations and virtual disks before upgrading.
- This command downloads the latest contents of the `main` branch; it does not verify a signed release.
