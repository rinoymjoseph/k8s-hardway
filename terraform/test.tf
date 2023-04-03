terraform {
  required_providers {
    proxmox = {
      source    =   "Telmate/proxmox"
      version   =   "2.9.14"
    }
  }
}

provider "proxmox" {
  # Configuration options
  pm_api_url    =   "https://192.168.0.111:8006/api2/json"
  pm_user       =   "root@pam"
  pm_password   =   "welcome123#"
}

# Provision 
resource "proxmox_vm_qemu" "resource-name" {
  name          = "test-vm"
  vmid          = 145
  target_node   = "proxmox"
  clone         = "Ubuntu-Server-22.04"
  full_clone    = false
  memory        = 2048
  network   {
    model       = "virtio"
    macaddr     = "86:AC:41:36:AD:BE"
    bridge      = "vmbr0"
    firewall    = true
  }

}