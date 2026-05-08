# Talos machine secrets — one per cluster
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# Talos client configuration
data "talos_client_configuration" "cluster" {
  cluster_name         = var.name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [for _, node in local.cp_nodes : node.ip]
}

locals {
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
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
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

}

# Worker machine configuration
data "talos_machine_configuration" "wk" {
  for_each = local.wk_nodes

  cluster_name       = var.name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
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
resource "talos_machine_configuration_apply" "node" {
  for_each = local.all_nodes

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = each.value.role == "cp" ? data.talos_machine_configuration.cp[each.key].machine_configuration : data.talos_machine_configuration.wk[each.key].machine_configuration
  node                        = each.value.ip

  depends_on = [
    proxmox_virtual_environment_vm.talos,
    data.talos_machine_configuration.cp,
    data.talos_machine_configuration.wk,
  ]
}

# Bootstrap the first control plane node
resource "talos_machine_bootstrap" "first_cp" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.all_nodes[local.first_cp_name].ip

  depends_on = [talos_machine_configuration_apply.node]
}

# Retrieve admin kubeconfig
resource "talos_cluster_kubeconfig" "admin" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.all_nodes[local.first_cp_name].ip

  depends_on = [talos_machine_bootstrap.first_cp]
}



resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.admin.kubeconfig_raw
  filename        = "${path.root}/files/secrets/${var.name}_kubeconfig.yaml"
  file_permission = "0600"
}

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.cluster.talos_config
  filename        = "${path.root}/files/secrets/${var.name}_talosconfig.yaml"
  file_permission = "0600"
}

# --- Graceful Node Cleanup (Stage 3: Remove from K8s after VM is gone) ---
resource "terraform_data" "k8s_node_cleanup" {
  for_each = local.all_nodes

  input = {
    node_name       = each.key
    kubeconfig_path = "${path.root}/files/secrets/${var.name}_kubeconfig.yaml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Destruction Stage 3: Removing node ${self.input.node_name} from Kubernetes API..."
      kubectl --kubeconfig "${self.input.kubeconfig_path}" \
        delete node "${self.input.node_name}" \
        --ignore-not-found || true
    EOT
  }
}

# --- Graceful Node Cleanup (Stage 1: Talos Reset before VM is touched) ---
resource "terraform_data" "talos_reset" {
  for_each = local.all_nodes

  input = {
    node_ip          = each.value.ip
    talosconfig_path = "${path.root}/files/secrets/${var.name}_talosconfig.yaml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Stage 1: Resetting Talos node at ${self.input.node_ip}..."
      talosctl --talosconfig "${self.input.talosconfig_path}" \
        -n "${self.input.node_ip}" \
        reset --graceful || true
    EOT
  }


  # This ensures reset happens BEFORE VM destruction
  depends_on = [proxmox_virtual_environment_vm.talos]
}
