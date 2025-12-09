resource "proxmox_virtual_environment_pool" "production" {
  pool_id = "production"
  comment = "VMs and Containers for the main Kubernetes cluster (Talos/Flatcar) and core services."
}

resource "proxmox_virtual_environment_pool" "development" {
  pool_id = "development"
  comment = "VMs for testing, temporary labs, and general utility purposes (Debian/Ubuntu)."
}
