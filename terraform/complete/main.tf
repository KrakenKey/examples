# Domain, DNS records and verification ------------------------------------

resource "krakenkey_domain" "this" {
  hostname = var.domain
}

resource "cloudflare_dns_record" "kk_verify" {
  zone_id = var.cloudflare_zone_id
  name    = krakenkey_domain.this.txt_record_name
  type    = "TXT"
  content = krakenkey_domain.this.txt_record_value
  ttl     = 1
}

resource "cloudflare_dns_record" "kk_acme" {
  zone_id = var.cloudflare_zone_id
  name    = krakenkey_domain.this.cname_record_name
  type    = "CNAME"
  content = krakenkey_domain.this.cname_record_value
  ttl     = 1
  proxied = false
}

# Nothing in the graph links the TXT record to verification, so depends_on
# states it.
resource "krakenkey_domain_verification" "this" {
  domain_id = krakenkey_domain.this.id

  timeouts = {
    create = "15m"
  }

  depends_on = [cloudflare_dns_record.kk_verify]
}

# Private key and certificate --------------------------------------------
#
# The key is ephemeral: it never reaches plan or state. It is stored in Vault
# through a write-only argument, and the CSR is built from the same key in the
# same run. Both are pinned to key_version, so the key only changes when you
# bump it.

ephemeral "tls_private_key" "this" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "vault_kv_secret_v2" "key" {
  mount                = var.vault_mount
  name                 = "tls/${var.domain}/key"
  data_json_wo         = jsonencode({ private_key_pem = ephemeral.tls_private_key.this.private_key_pem })
  data_json_wo_version = var.key_version
}

resource "tls_cert_request" "this" {
  private_key_pem_wo         = ephemeral.tls_private_key.this.private_key_pem
  private_key_pem_wo_version = var.key_version

  subject {
    common_name = var.dns_names[0]
  }
  dns_names = var.dns_names
}

resource "krakenkey_certificate" "this" {
  csr_pem = tls_cert_request.this.cert_request_pem

  # Every name in the CSR must be on a verified domain, and the
  # _acme-challenge CNAME must be in place before issuance starts.
  depends_on = [
    krakenkey_domain_verification.this,
    cloudflare_dns_record.kk_acme,
  ]
}

# Deploy -------------------------------------------------------------------
#
# A bundle with the certificate and key together, for whatever serves it.
# KrakenKey renews the certificate on its own; expires_at_unix changes when it
# does, so the next apply rewrites the bundle with the new certificate. The key
# is read back from Vault, never regenerated.

ephemeral "vault_kv_secret_v2" "key" {
  mount = vault_kv_secret_v2.key.mount
  # Tied to the computed id, so on the first run the read waits until the
  # secret exists instead of failing at plan time.
  name = vault_kv_secret_v2.key.id != null ? vault_kv_secret_v2.key.name : null
}

resource "vault_kv_secret_v2" "deployed" {
  mount = var.vault_mount
  name  = "deploy/${var.domain}"
  data_json_wo = jsonencode({
    fullchain_pem   = krakenkey_certificate.this.fullchain_pem
    private_key_pem = ephemeral.vault_kv_secret_v2.key.data.private_key_pem
  })
  data_json_wo_version = krakenkey_certificate.this.expires_at_unix
}

# Monitoring and alerts ----------------------------------------------------

resource "krakenkey_endpoint" "this" {
  for_each = toset(var.dns_names)

  host  = each.value
  label = "Managed by Terraform"
}

resource "krakenkey_alert_channel" "slack" {
  type           = "slack"
  name           = "Certificates for ${var.domain}"
  url_wo         = var.slack_webhook_url
  url_wo_version = 1
}
