output "kubeconfig" {
  description = "Raw kubeconfig YAML for the cluster"
  value       = module.vm_talos.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "Raw talosconfig YAML for the cluster"
  value       = module.vm_talos.talosconfig
  sensitive   = true
}

output "node_ips" {
  description = "Map of node name to IP address"
  value       = module.vm_talos.node_ips
}

output "vm_ids" {
  description = "Map of node name to Proxmox VM ID"
  value       = module.vm_talos.vm_ids
}
