variable "iso_url" {
  type        = string
  description = "Path to the MikroTik CHR raw disk image"
}

variable "iso_checksum" {
  type        = string
  default     = "none"
  description = "Checksum of the disk image (set to 'none' to skip verification)"
}

variable "ssh_username" {
  type    = string
  default = "admin"
}

variable "ssh_password" {
  type      = string
  default   = "Everest1953!"
  sensitive = true
}

variable "vm_cpus" {
  type    = number
  default = 1
}

variable "vm_memory" {
  type    = number
  default = 256
}

variable "headless" {
  type    = bool
  default = true
}

variable "output_directory" {
  type    = string
  default = "output-chr"
}

variable "vm_name" {
  type    = string
  default = "chr-7.20.8"
}
