output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}



output "node_ips" {
  value = { for name, node in local.all_nodes : name => node.ip }
}

output "vm_ids" {
  value = { for name, vm in proxmox_virtual_environment_vm.talos : name => vm.vm_id }
}

output "health_status" {
  value = "Provisioning complete. If stuck, check 'talosctl --talosconfig files/secrets/${var.name}_talosconfig.yaml health --endpoints ${join(",", [for node in local.cp_nodes : node.ip])}'"
}
