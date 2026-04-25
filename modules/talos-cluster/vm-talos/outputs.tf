output "kubeconfig" {
  description = "Raw kubeconfig YAML for the cluster"
  value       = talos_cluster_kubeconfig.admin.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Raw talosconfig YAML for the cluster"
  value       = data.talos_client_configuration.cluster.talos_config
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file on disk"
  value       = local_file.kubeconfig.filename
}

output "node_ips" {
  description = "Map of node name to IP address"
  value       = { for name, node in local.all_nodes : name => node.ip }
}

output "vm_ids" {
  description = "Map of node name to Proxmox VM ID"
  value       = { for name, vm in proxmox_virtual_environment_vm.talos : name => vm.vm_id }
}
