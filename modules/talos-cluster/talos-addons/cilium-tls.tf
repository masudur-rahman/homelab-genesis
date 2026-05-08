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

# Hubble server TLS (agents)
# Cilium peer uses <svc>.<cluster-name>.hubble-grpc.cilium.io as TLS server name
# Wildcard certs only match one subdomain level, so need both patterns
resource "tls_private_key" "hubble_server_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "hubble_server" {
  private_key_pem = tls_private_key.hubble_server_key.private_key_pem

  subject {
    common_name  = "*.${var.cilium_cluster_name}.hubble-grpc.cilium.io"
    organization = "Cilium"
  }

  dns_names = [
    "*.hubble-grpc.cilium.io",
    "*.${var.cilium_cluster_name}.hubble-grpc.cilium.io",
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
resource "tls_private_key" "hubble_relay_client_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "hubble_relay_client" {
  private_key_pem = tls_private_key.hubble_relay_client_key.private_key_pem

  subject {
    common_name  = "*.hubble-relay.cilium.io"
    organization = "Cilium"
  }

  dns_names = [
    "*.hubble-relay.cilium.io",
  ]
}

resource "tls_locally_signed_cert" "hubble_relay_client_cert" {
  cert_request_pem   = tls_cert_request.hubble_relay_client.cert_request_pem
  ca_private_key_pem = tls_private_key.cilium_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.cilium_ca.cert_pem

  validity_period_hours = 26280 # ~3 years
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]
}

# Hubble relay server TLS — presented by relay to hubble-ui / hubble-cli
resource "tls_private_key" "hubble_relay_server_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "hubble_relay_server" {
  private_key_pem = tls_private_key.hubble_relay_server_key.private_key_pem

  subject {
    common_name  = "*.hubble-relay.cilium.io"
    organization = "Cilium"
  }

  dns_names = [
    "*.hubble-relay.cilium.io",
    "hubble-relay.kube-system.svc.cluster.local", # in-cluster access
    "hubble-relay",
  ]
}

resource "tls_locally_signed_cert" "hubble_relay_server_cert" {
  cert_request_pem   = tls_cert_request.hubble_relay_server.cert_request_pem
  ca_private_key_pem = tls_private_key.cilium_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.cilium_ca.cert_pem

  validity_period_hours = 26280
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}