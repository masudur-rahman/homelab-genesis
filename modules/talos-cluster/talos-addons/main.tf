terraform {
  required_providers {
    tls = { source = "hashicorp/tls" }
  }
}

locals {
  templates_dir   = "${path.module}/templates"
  helm_dir        = "${path.root}/files/helm"
  lb_ipam_enabled = var.lb_ipam != null

  # Gateway API experimental channel: superset of standard + all experimental
  # CRDs. Cilium's gateway controller needs the experimental TLSRoute CRD
  # (TLSRouteList), absent from standard-install.yaml.
  gateway_api_url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/experimental-install.yaml"
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

# --- Cilium LB-IPAM pools + L2 announcement policy ---

resource "local_file" "cilium_lb_ipam" {
  count = local.lb_ipam_enabled ? 1 : 0

  content = templatefile("${local.templates_dir}/cilium-lb-ipam.yaml.tftpl", {
    range_start_ip = cidrhost(var.lb_ipam.network_cidr, var.lb_ipam.range_start)
    range_stop_ip  = cidrhost(var.lb_ipam.network_cidr, var.lb_ipam.range_stop)
    l2_interface   = var.lb_ipam.l2_interface
  })
  filename        = "${local.helm_dir}/${var.cluster_name}-cilium-lb-ipam.yaml"
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

# --- Gateway API CRDs (required before Cilium gatewayAPI feature) ---

resource "terraform_data" "gateway_api_crds" {
  input = {
    kubeconfig = var.kubeconfig_path
    url        = local.gateway_api_url
  }

  triggers_replace = [local.gateway_api_url]

  provisioner "local-exec" {
    # kubectl apply returns before CRDs are Established in API discovery.
    # Wait so the subsequent Cilium helm install sees the GatewayClass CRD
    # via its capability check (else the GatewayClass template is skipped).
    command     = <<-EOT
      kubectl apply -f ${self.input.url} --kubeconfig ${self.input.kubeconfig}
      kubectl wait --for condition=established --timeout=60s \
        crd/gatewayclasses.gateway.networking.k8s.io \
        crd/gateways.gateway.networking.k8s.io \
        crd/httproutes.gateway.networking.k8s.io \
        crd/tlsroutes.gateway.networking.k8s.io \
        --kubeconfig ${self.input.kubeconfig}
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "kubectl delete -f ${self.output.url} --kubeconfig ${self.output.kubeconfig} 2>/dev/null || true"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [terraform_data.wait_for_api]
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

  depends_on = [terraform_data.gateway_api_crds]
}

# --- Apply Cilium LB-IPAM pools + L2 policy (CRDs ship with Cilium) ---

resource "terraform_data" "cilium_lbipam_apply" {
  count = local.lb_ipam_enabled ? 1 : 0

  input = {
    kubeconfig = var.kubeconfig_path
    manifest   = local_file.cilium_lb_ipam[0].filename
  }

  triggers_replace = [
    sha256(local_file.cilium_lb_ipam[0].content),
  ]

  provisioner "local-exec" {
    command     = "kubectl apply -f ${self.input.manifest} --kubeconfig ${self.input.kubeconfig}"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "kubectl delete -f ${self.output.manifest} --kubeconfig ${self.output.kubeconfig} 2>/dev/null || true"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [terraform_data.cilium_install]
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
