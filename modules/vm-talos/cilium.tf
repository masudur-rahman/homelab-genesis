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

# Hubble relay TLS key + certificate signed by Cilium CA
resource "tls_private_key" "hubble_tls_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "hubble_grpc" {
  private_key_pem = tls_private_key.hubble_tls_key.private_key_pem

  subject {
    common_name  = "*.hubble-relay.cilium.io"
    organization = "Cilium"
  }

  dns_names = [
    "*.hubble-relay.cilium.io",
  ]
}

resource "tls_locally_signed_cert" "hubble_tls_cert" {
  cert_request_pem   = tls_cert_request.hubble_grpc.cert_request_pem
  ca_private_key_pem = tls_private_key.cilium_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.cilium_ca.cert_pem

  validity_period_hours = 26280 # ~3 years
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

# Render Cilium Helm chart with custom values
data "helm_template" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version

  values = [
    templatefile("${path.module}/templates/cilium-values.yaml.tftpl", {
      cilium_ca_cert  = base64encode(tls_self_signed_cert.cilium_ca.cert_pem)
      cilium_ca_key   = base64encode(tls_private_key.cilium_ca.private_key_pem)
      hubble_tls_cert = base64encode(tls_locally_signed_cert.hubble_tls_cert.cert_pem)
      hubble_tls_key  = base64encode(tls_private_key.hubble_tls_key.private_key_pem)
    })
  ]
}
