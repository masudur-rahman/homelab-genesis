# Cilium CA key + self-signed certificate (3-year validity)
resource "tls_private_key" "cilium_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "cilium_ca" {
  private_key_pem = tls_private_key.cilium_ca.private_key_pem

  subject {
    common_name  = "Cilium CA"
    organization = "Cilium"
  }

  is_ca_certificate     = true
  validity_period_hours = 26280 # ~3 years
  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

# Hubble server TLS (agents) — SAN: *.hubble-grpc.cilium.io
resource "tls_private_key" "hubble_server_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "hubble_server" {
  private_key_pem = tls_private_key.hubble_server_key.private_key_pem

  subject {
    common_name  = "*.hubble-grpc.cilium.io"
    organization = "Cilium"
  }

  dns_names = [
    "*.hubble-grpc.cilium.io",
  ]
}

resource "tls_locally_signed_cert" "hubble_server_cert" {
  cert_request_pem   = tls_cert_request.hubble_server.cert_request_pem
  ca_private_key_pem = tls_private_key.cilium_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.cilium_ca.cert_pem

  validity_period_hours = 26280 # ~3 years
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}

# Hubble relay client TLS — SAN: *.hubble-relay.cilium.io
resource "tls_private_key" "hubble_relay_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "hubble_relay" {
  private_key_pem = tls_private_key.hubble_relay_key.private_key_pem

  subject {
    common_name  = "*.hubble-relay.cilium.io"
    organization = "Cilium"
  }

  dns_names = [
    "*.hubble-relay.cilium.io",
  ]
}

resource "tls_locally_signed_cert" "hubble_relay_cert" {
  cert_request_pem   = tls_cert_request.hubble_relay.cert_request_pem
  ca_private_key_pem = tls_private_key.cilium_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.cilium_ca.cert_pem

  validity_period_hours = 26280 # ~3 years
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]
}

# Render Cilium Helm chart with custom values
data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  kube_version = "1.32.3"
  version      = var.cilium_version

  values = [
    templatefile("${path.module}/templates/cilium-values.yaml.tftpl", {
      cilium_ca_cert         = base64encode(tls_self_signed_cert.cilium_ca.cert_pem)
      cilium_ca_key          = base64encode(tls_private_key.cilium_ca.private_key_pem)
      hubble_server_cert     = base64encode(tls_locally_signed_cert.hubble_server_cert.cert_pem)
      hubble_server_key      = base64encode(tls_private_key.hubble_server_key.private_key_pem)
      hubble_relay_cert      = base64encode(tls_locally_signed_cert.hubble_relay_cert.cert_pem)
      hubble_relay_key       = base64encode(tls_private_key.hubble_relay_key.private_key_pem)
      cluster_vip            = var.cluster_vip
      cluster_endpoint_port  = var.cluster_endpoint_port
    })
  ]

  depends_on = [
    tls_locally_signed_cert.hubble_server_cert,
    tls_locally_signed_cert.hubble_relay_cert,
  ]
}
