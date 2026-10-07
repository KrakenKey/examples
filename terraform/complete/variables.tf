variable "domain" {
  description = "Domain to register with KrakenKey, for example example.com."
  type        = string
}

variable "dns_names" {
  description = "Names on the certificate. Each must be the domain or a name under it."
  type        = list(string)
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone that holds the domain."
  type        = string
}

variable "vault_mount" {
  description = "Vault KV v2 mount for the private key and the deployed bundle."
  type        = string
  default     = "secret"
}

variable "key_version" {
  description = "Bump to rotate the private key. Nothing about the key changes until this does."
  type        = number
  default     = 1
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook for alerts. Pass it as TF_VAR_slack_webhook_url; never commit it."
  type        = string
  sensitive   = true
  ephemeral   = true
}
