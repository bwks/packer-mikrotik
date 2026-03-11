packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "chr" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  disk_image   = true

  output_directory = var.output_directory
  vm_name          = "${var.vm_name}.qcow2"
  format           = "qcow2"

  accelerator  = "kvm"
  machine_type = "q35"
  cpus         = var.vm_cpus
  memory       = var.vm_memory
  headless     = var.headless

  disk_interface = "virtio"
  net_device     = "virtio-net"

  boot_wait = "45s"
  boot_command = [
    # Login as admin with empty password
    "admin<enter>",
    "<wait3>",
    "<enter>",
    # Wait for MikroTik banner and license prompt: "Do you want to see the software license? [Y/n]:"
    "<wait10>",
    "n<enter>",
    # Wait for "new password>" prompt
    "<wait5>",
    "${var.ssh_password}<enter>",
    # Wait for "repeat new password>" prompt
    "<wait3>",
    "${var.ssh_password}<enter>",
    "<wait5>",
  ]

  communicator = "ssh"
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "5m"

  # Rename the QEMU build NIC so it doesn't claim ether1 on deploy,
  # add the ZTP scheduler, then shut down.
  shutdown_command = "/interface ethernet set 0 name=temp; /system scheduler add name=sherpa-ztp interval=1m on-event=\"if ([/file find name=sata1/config.rsc] != \\\"\\\") do={ /import sata1/config.rsc; /system scheduler remove sherpa-ztp }\"; /system scheduler add name=sherpa-ssh-key interval=1m on-event=\"if ([/file find name=sata1/sherpa_ssh_key.pub] != \\\"\\\") do={ /user ssh-keys import public-key-file=sata1/sherpa_ssh_key.pub user=sherpa; /system scheduler remove sherpa-ssh-key }\"; /system shutdown"
  shutdown_timeout = "2m"
}

build {
  sources = ["source.qemu.chr"]
}
