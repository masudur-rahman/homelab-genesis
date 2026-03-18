# Proxmox CSI role with required privileges
resource "proxmox_virtual_environment_role" "csi" {
  role_id = "kubernetes-csi"
  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
  ]
}

# Dedicated user for CSI
resource "proxmox_virtual_environment_user" "csi" {
  user_id = "kubernetes-csi@pve"
  comment = "Proxmox CSI plugin service account"
  enabled = true
}

# API token for CSI (no privilege separation)
resource "proxmox_virtual_environment_user_token" "csi" {
  user_id               = proxmox_virtual_environment_user.csi.user_id
  token_name            = "csi"
  privileges_separation = false
  comment               = "Token for Proxmox CSI plugin"
}

# ACL binding: CSI role on root path
resource "proxmox_virtual_environment_acl" "csi" {
  path    = "/"
  role_id = proxmox_virtual_environment_role.csi.role_id
  user_id = proxmox_virtual_environment_user.csi.user_id

  propagate = true
}

# Render Proxmox CSI Helm chart
data "helm_template" "proxmox_csi" {
  name       = "proxmox-csi-plugin"
  namespace  = "csi-proxmox"
  repository = "oci://ghcr.io/sergelogvinov/charts"
  chart      = "proxmox-csi-plugin"
  version    = var.proxmox_csi_version

  create_namespace = true

  values = [
    templatefile("${path.module}/templates/proxmox-csi-values.yaml.tftpl", {
      pm_api_endpoint = var.pm_api_endpoint
      token_id        = "${proxmox_virtual_environment_user_token.csi.user_id}!${proxmox_virtual_environment_user_token.csi.token_name}"
      token_secret    = proxmox_virtual_environment_user_token.csi.value
      region          = var.topology_region
      zone            = var.topology_zone
    })
  ]
}
