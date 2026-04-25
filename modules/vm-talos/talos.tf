# Talos machine secrets — one per cluster
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# Talos client configuration
data "talos_client_configuration" "this" {
  cluster_name         = var.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for _, node in local.cp_nodes : node.ip]
}

# Inline manifests: Cilium + Proxmox CSI rendered Helm charts
locals {
  inline_manifests = [
    {
      name     = "cilium"
      contents = data.helm_template.cilium.manifest
    },
    {
      name = "csi-proxmox-namespace"
      contents = yamlencode({
        apiVersion = "v1"
        kind       = "Namespace"
        metadata = {
          name = "csi-proxmox"
        }
      })
    },
    {
      name     = "proxmox-csi"
      contents = data.helm_template.proxmox_csi.manifest
    },
  ]

  # CP-only: VIP on interface
  cp_vip_patch = {
    for name, node in local.cp_nodes : name => jsonencode({
      machine = {
        network = {
          interfaces = [{
            interface = "ens18"
            vip = {
              ip = var.cluster_vip
            }
          }]
        }
      }
    })
  }

  # CP-only: cluster overrides (single value, not per-node)
  cp_cluster_patch = jsonencode({
    cluster = {
      network = {
        cni = {
          name = "none"
        }
      }
      proxy = {
        disabled = true
      }
      inlineManifests = local.inline_manifests
      extraManifests = [
        "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
        "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml",
      ]
    }
  })

}

# Control plane machine configuration
data "talos_machine_configuration" "cp" {
  for_each = local.cp_nodes

  cluster_name       = var.name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = compact([
    templatefile("${path.module}/templates/machine-config.yaml.tftpl", {
      ip            = each.value.ip
      gateway       = local.network_gateway
      nameservers   = var.nameservers
      region        = var.topology_region
      zone          = var.topology_zone
      node_labels   = each.value.node_labels
      node_taints   = each.value.node_taints
      install_image = var.talos_install_image
    }),
    local.cp_vip_patch[each.key],
    local.cp_cluster_patch,
    each.value.ephemeral_volume_grow ? templatefile("${path.module}/templates/ephemeral-volume.yaml.tftpl", {
      grow     = each.value.ephemeral_volume_grow
      max_size = each.value.ephemeral_volume_max_size
      min_size = each.value.ephemeral_volume_min_size
    }) : "",
  ])

  depends_on = [
    data.helm_template.cilium,
    data.helm_template.proxmox_csi,
  ]
}

# Worker machine configuration
data "talos_machine_configuration" "wk" {
  for_each = local.wk_nodes

  cluster_name       = var.name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = compact([
    templatefile("${path.module}/templates/machine-config.yaml.tftpl", {
      ip            = each.value.ip
      gateway       = local.network_gateway
      nameservers   = var.nameservers
      region        = var.topology_region
      zone          = var.topology_zone
      node_labels   = each.value.node_labels
      node_taints   = each.value.node_taints
      install_image = var.talos_install_image
    }),
    each.value.ephemeral_volume_grow ? templatefile("${path.module}/templates/ephemeral-volume.yaml.tftpl", {
      grow     = each.value.ephemeral_volume_grow
      max_size = each.value.ephemeral_volume_max_size
      min_size = each.value.ephemeral_volume_min_size
    }) : "",
  ])
}

# Apply machine configuration to all nodes
resource "talos_machine_configuration_apply" "this" {
  for_each = local.all_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = each.value.role == "cp" ? data.talos_machine_configuration.cp[each.key].machine_configuration : data.talos_machine_configuration.wk[each.key].machine_configuration
  node                        = each.value.ip

  depends_on = [
    proxmox_virtual_environment_vm.talos,
    data.talos_machine_configuration.cp,
    data.talos_machine_configuration.wk,
  ]
}

# Bootstrap the first control plane node
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.all_nodes[local.first_cp_name].ip

  depends_on = [talos_machine_configuration_apply.this]
}

# Retrieve admin kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.all_nodes[local.first_cp_name].ip

  depends_on = [talos_machine_bootstrap.this]
}


resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.root}/files/secrets/${var.name}_kubeconfig.yaml"
  file_permission = "0600"
}

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.root}/files/secrets/${var.name}_talosconfig.yaml"
  file_permission = "0600"
}

# Wait for cluster health
data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for _, node in local.cp_nodes : node.ip]
  control_plane_nodes  = [for _, node in local.cp_nodes : node.ip]
  worker_nodes         = [for _, node in local.wk_nodes : node.ip]

  depends_on = [talos_machine_bootstrap.this]
}
