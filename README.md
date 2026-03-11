# Packer MikroTik CHR

Packer template that takes a raw MikroTik CHR disk image and bakes in ZTP (zero-touch provisioning) schedulers. The output is a qcow2 image ready for deployment.

## What it does

The build boots the CHR image in QEMU, completes the first-boot setup, adds two ZTP schedulers via `shutdown_command`, and shuts down.

Two schedulers are baked in:

- **`sherpa-ztp`** — checks every minute for `sata1/config.rsc`. If found, imports the config and removes itself.
- **`sherpa-ssh-key`** — checks every minute for `sata1/sherpa_ssh_key.pub`. If found, imports it as an SSH key for the `sherpa` user and removes itself.

The build also renames the QEMU build NIC (`/interface ethernet set 0 name=temp`) to avoid interface naming conflicts on deploy.

## Prerequisites

- [Packer](https://www.packer.io/) >= 1.7
- QEMU with KVM support (`qemu-system-x86_64`, `/dev/kvm`)
- MikroTik CHR raw disk image (e.g. `chr-7.20.8.img`)

## Quick start

```bash
# 1. Download the CHR image
wget https://download.mikrotik.com/routeros/7.20.8/chr-7.20.8.img.zip
unzip chr-7.20.8.img.zip

# 2. Create your variables file
cp mikrotik-chr.auto.pkrvars.hcl.example mikrotik-chr.auto.pkrvars.hcl

# 3. Install the QEMU plugin
packer init .

# 4. Build
packer build .
```

The output image is written to `output-chr/chr-7.20.8.qcow2`.

## Variables

| Variable | Default | Description |
|---|---|---|
| `iso_url` | *(required)* | Path to the CHR raw disk image |
| `iso_checksum` | `none` | Image checksum (or `none` to skip) |
| `ssh_username` | `admin` | RouterOS username |
| `ssh_password` | `Everest1953!` | Temporary password set during build |
| `vm_cpus` | `1` | VM CPU count |
| `vm_memory` | `256` | VM memory in MB |
| `headless` | `true` | Run QEMU without display |
| `output_directory` | `output-chr` | Output directory for the qcow2 image |
| `vm_name` | `chr-7.20.8` | Output filename (`.qcow2` appended) |

Override variables on the command line or in `mikrotik-chr.auto.pkrvars.hcl`:

```bash
packer build -var "vm_name=chr-custom" .
```

## How the build works

1. **Boot** — QEMU boots the raw CHR image with KVM acceleration
2. **First-boot setup** — `boot_command` types keystrokes via VNC to complete the RouterOS first-boot sequence (login, decline license, set temporary password)
3. **SSH connect** — Packer connects via SSH to confirm the VM is ready
4. **Shutdown** — `shutdown_command` runs via SSH to rename the QEMU NIC, add both ZTP schedulers, and shut down the VM
5. **Convert** — Packer converts the disk to qcow2

## File structure

```
mikrotik-chr.pkr.hcl                  # Main Packer template
variables.pkr.hcl                     # Variable declarations
mikrotik-chr.auto.pkrvars.hcl         # Variable values (git-ignored)
mikrotik-chr.auto.pkrvars.hcl.example # Example variables file
.gitignore                            # Ignores build artifacts and images
```

## Troubleshooting

**Build fails with "gtk initialization failed"** — You're on a headless server. Make sure `headless = true` (the default).

**SSH timeout** — The `boot_command` timing may need adjustment. The 45-second `boot_wait` is conservative but some systems may need more. Check `boot_wait` and the `<waitN>` delays in `boot_command`.

**"Qemu failed to start"** — Ensure KVM is available (`ls /dev/kvm`). If not, load the module: `modprobe kvm_intel` or `modprobe kvm_amd`.
