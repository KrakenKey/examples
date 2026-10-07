# Read-only check of a certificate KrakenKey already manages. It only uses data
# sources, so it creates nothing, needs no remote state, and doesn't count
# toward issuance limits. .github/workflows/terraform-canary.yml runs it daily.

terraform {
  required_version = ">= 1.11"

  required_providers {
    krakenkey = {
      source  = "krakenkey/krakenkey"
      version = "~> 0.1"
    }
  }
}

# Reads the API key from KK_API_KEY. A key with only the certs:read scope is
# enough.
provider "krakenkey" {}

variable "certificate_id" {
  description = "ID of the certificate to check."
  type        = string
}

variable "min_days_left" {
  description = "Fail if the certificate expires within this many days."
  type        = number
  default     = 14
}

data "krakenkey_certificate" "this" {
  id = var.certificate_id
}

output "status" {
  value = data.krakenkey_certificate.this.status

  precondition {
    condition     = data.krakenkey_certificate.this.status == "issued"
    error_message = "Certificate ${var.certificate_id} is ${data.krakenkey_certificate.this.status}, not issued."
  }
}

output "expires_at" {
  value = data.krakenkey_certificate.this.expires_at

  precondition {
    condition     = timecmp(data.krakenkey_certificate.this.expires_at, timeadd(plantimestamp(), "${var.min_days_left * 24}h")) > 0
    error_message = "Certificate ${var.certificate_id} expires at ${data.krakenkey_certificate.this.expires_at}, within ${var.min_days_left} days."
  }
}

output "renewal_count" {
  value = data.krakenkey_certificate.this.renewal_count
}

# The leaf in fullchain_pem must be the same certificate as cert_pem, followed
# by at least one intermediate.
output "chain_length" {
  value = length(regexall("-----BEGIN CERTIFICATE-----", data.krakenkey_certificate.this.fullchain_pem))

  precondition {
    condition     = startswith(data.krakenkey_certificate.this.fullchain_pem, trimspace(data.krakenkey_certificate.this.cert_pem)) && length(regexall("-----BEGIN CERTIFICATE-----", data.krakenkey_certificate.this.fullchain_pem)) >= 2
    error_message = "fullchain_pem doesn't start with the leaf certificate or has no intermediates."
  }
}
