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

# Control plane machine configuration
data "talos_machine_configuration" "cp" {
  for_each = local.cp_nodes

  cluster_name       = var.name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    # Network: static IP + gateway + nameservers
    jsonencode({
      machine = {
        network = {
          hostname    = each.key
          nameservers = var.nameservers
          interfaces = [{
            interface = "eth0"
            addresses = ["${each.value.ip}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = local.network_gateway
            }]
            vip = {
              ip = var.cluster_vip
            }
          }]
        }
        install = {
          disk = "/dev/sda"
        }
        nodeLabels = {
          "topology.kubernetes.io/region" = var.topology_region
          "topology.kubernetes.io/zone"   = var.topology_zone
        }
      }
    }),

    # Cluster: disable default CNI and kube-proxy (Cilium replaces both)
    jsonencode({
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
    }),
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

  config_patches = [
    # Network: static IP + gateway + nameservers (no VIP on workers)
    jsonencode({
      machine = {
        network = {
          hostname    = each.key
          nameservers = var.nameservers
          interfaces = [{
            interface = "eth0"
            addresses = ["${each.value.ip}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = local.network_gateway
            }]
          }]
        }
        install = {
          disk = "/dev/sda"
        }
        nodeLabels = {
          "topology.kubernetes.io/region" = var.topology_region
          "topology.kubernetes.io/zone"   = var.topology_zone
        }
      }
    }),
  ]
}

# Inline manifests: Cilium + Proxmox CSI rendered Helm charts
locals {
  inline_manifests = [
    {
      name     = "cilium"
      contents = data.helm_template.cilium.manifest
    },
    {
      name     = "proxmox-csi"
      contents = data.helm_template.proxmox_csi.manifest
    },
  ]
}
