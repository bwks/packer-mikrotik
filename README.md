# Packer MikroTik CHR

Packer template that takes a raw MikroTik CHR disk image and bakes in a ZTP (zero-touch provisioning) scheduler. The output is a qcow2 image ready for deployment.

## What it does

The build boots the CHR image in QEMU, completes the first-boot setup, uploads a configuration script, then runs `/system reset-configuration` to produce a clean image with only the ZTP scheduler baked in.

The ZTP scheduler (`sherpa-ztp`) runs every minute and checks for `sata1/config.rsc`. If found, it imports the config and removes itself:

```routeros
/system scheduler add name=sherpa-ztp interval=1m \
  on-event="if ([/file find name=sata1/config.rsc] != \"\") do={ \
    /import sata1/config.rsc; /system scheduler remove sherpa-ztp }"
```

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
4. **Upload script** — The file provisioner uploads `afterreset.rsc` containing the ZTP scheduler config
5. **Reset and shutdown** — `shutdown_command` runs `/system reset-configuration` with `run-after-reset=afterreset.rsc`. This wipes the interface database (removing the QEMU build NIC's footprint) and reboots. The after-reset script adds the scheduler and shuts down the VM
6. **Convert** — Packer converts the disk to qcow2

### Why reset-configuration?

QEMU adds a virtio-net NIC during the build. RouterOS saves this NIC in its interface database. Without the reset, deploying the image to hardware with different NICs causes interface renaming (ether1 becomes ether2, ether2 becomes ether3, etc.) because the QEMU NIC's ether1 slot is still claimed. The reset wipes the interface database so deployed NICs get their proper default names.

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

**Interface renaming on deploy** — This should be fixed by the `reset-configuration` step. If it recurs, verify the build log shows "Uploading ... afterreset.rsc" and the shutdown_command completing.
