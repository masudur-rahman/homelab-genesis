terraform {
  required_providers {
    tls = { source = "hashicorp/tls" }
  }
}

locals {
  templates_dir = "${path.module}/templates"
  helm_dir      = "${path.root}/files/helm"
}

# --- Cilium Helm values ---

resource "local_file" "cilium_values" {
  content = templatefile("${local.templates_dir}/cilium-values.yaml.tftpl", {
    cilium_ca_cert           = base64encode(tls_self_signed_cert.cilium_ca.cert_pem)
    cilium_ca_key            = base64encode(tls_private_key.cilium_ca.private_key_pem)
    hubble_server_cert       = base64encode(tls_locally_signed_cert.hubble_server_cert.cert_pem)
    hubble_server_key        = base64encode(tls_private_key.hubble_server_key.private_key_pem)
    hubble_relay_client_cert = base64encode(tls_locally_signed_cert.hubble_relay_client_cert.cert_pem)
    hubble_relay_client_key  = base64encode(tls_private_key.hubble_relay_client_key.private_key_pem)
    hubble_relay_server_cert = base64encode(tls_locally_signed_cert.hubble_relay_server_cert.cert_pem)
    hubble_relay_server_key  = base64encode(tls_private_key.hubble_relay_server_key.private_key_pem)
    cluster_vip              = var.cluster_vip
    cluster_endpoint_port    = var.cluster_endpoint_port
  })
  filename        = "${local.helm_dir}/${var.cluster_name}-cilium-values.yaml"
  file_permission = "0600"

  depends_on = [
    tls_locally_signed_cert.hubble_server_cert,
    tls_locally_signed_cert.hubble_relay_client_cert,
    tls_locally_signed_cert.hubble_relay_server_cert,
  ]
}

# --- Proxmox CSI Helm values ---

resource "local_file" "csi_values" {
  content = templatefile("${local.templates_dir}/proxmox-csi-values.yaml.tftpl", {
    pm_api_endpoint = var.pm_api_endpoint
    token_id        = var.csi_token_id
    token_secret    = var.csi_token_secret
    region          = var.topology_region
    zone            = var.topology_zone
  })
  filename        = "${local.helm_dir}/${var.cluster_name}-csi-values.yaml"
  file_permission = "0600"
}

# --- Wait for Kubernetes API server ---

resource "terraform_data" "wait_for_api" {
  input = var.kubeconfig_path

  provisioner "local-exec" {
    command     = <<-EOT
      echo "Waiting for Kubernetes API server to become reachable..."
      for i in $(seq 1 60); do
        if kubectl --kubeconfig "${var.kubeconfig_path}" get --raw /version >/dev/null 2>&1; then
          echo "API server is reachable."
          exit 0
        fi
        echo "Attempt $i/60: API server not ready, retrying in 10s..."
        sleep 10
      done
      echo "ERROR: API server not reachable after 10 minutes."
      exit 1
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# --- Helm install: Cilium CNI ---

resource "terraform_data" "cilium_install" {
  input = var.kubeconfig_path

  triggers_replace = [
    var.cilium_version,
    sha256(local_file.cilium_values.content),
  ]

  provisioner "local-exec" {
    command     = <<-EOT
      helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
      helm repo update cilium
      helm upgrade --install cilium cilium/cilium \
        --namespace kube-system \
        --version "${var.cilium_version}" \
        --kubeconfig "${var.kubeconfig_path}" \
        -f "${local_file.cilium_values.filename}" \
        --wait --timeout 10m
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "helm uninstall cilium --namespace kube-system --kubeconfig ${self.output} 2>/dev/null || true"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [terraform_data.wait_for_api]
}

# --- Helm install: Proxmox CSI ---

resource "terraform_data" "csi_install" {
  input = var.kubeconfig_path

  triggers_replace = [
    var.proxmox_csi_version,
    sha256(local_file.csi_values.content),
  ]

  provisioner "local-exec" {
    command     = <<-EOT
      kubectl create namespace csi-proxmox \
        --kubeconfig "${var.kubeconfig_path}" 2>/dev/null || true
      kubectl label namespace csi-proxmox \
        pod-security.kubernetes.io/enforce=privileged \
        pod-security.kubernetes.io/audit=privileged \
        pod-security.kubernetes.io/warn=privileged \
        --kubeconfig "${var.kubeconfig_path}" --overwrite
      helm upgrade --install proxmox-csi-plugin \
        oci://ghcr.io/sergelogvinov/charts/proxmox-csi-plugin \
        --namespace csi-proxmox \
        --version "${var.proxmox_csi_version}" \
        --kubeconfig "${var.kubeconfig_path}" \
        -f "${local_file.csi_values.filename}" \
        --wait --timeout 10m
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "helm uninstall proxmox-csi-plugin --namespace csi-proxmox --kubeconfig ${self.output} 2>/dev/null || true"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [terraform_data.cilium_install]
}
