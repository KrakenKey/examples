output "certificate_id" {
  value = krakenkey_certificate.this.id
}

output "expires_at" {
  value = krakenkey_certificate.this.expires_at
}

output "deployed_secret" {
  description = "Vault path of the certificate and key bundle."
  value       = "${var.vault_mount}/deploy/${var.domain}"
}
