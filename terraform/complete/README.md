# Complete setup with Terraform

One configuration that takes a domain from nothing to a monitored, issued certificate:

1. Registers the domain with KrakenKey and publishes its TXT and `_acme-challenge` CNAME records in Cloudflare.
2. Verifies the domain once the TXT record is visible.
3. Creates an ECDSA P-256 private key as an ephemeral resource, stores it in Vault through a write-only argument, and builds the CSR from it. The key never appears in Terraform state or in a saved plan.
4. Issues the certificate. KrakenKey renews it on its own from then on.
5. Writes a bundle with the full chain and the key to Vault for whatever serves the certificate. `expires_at_unix` changes with every renewal, so the next `terraform apply` rewrites the bundle.
6. Monitors each name on the certificate and sends alerts to Slack.

The [Terraform guide](https://krakenkey.io/docs/integrations/terraform/) explains each step.

## Requirements

- Terraform 1.11 or later.
- A KrakenKey API key in `KK_API_KEY`.
- A Cloudflare API token with DNS edit on the zone, in `CLOUDFLARE_API_TOKEN`.
- A Vault server with a KV v2 mount, in `VAULT_ADDR` and `VAULT_TOKEN`.
- A Slack incoming webhook URL in `TF_VAR_slack_webhook_url`.

## Run it

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit it
terraform init
terraform apply
```

Issuance usually takes a few minutes, and `apply` waits for it.

Run `terraform apply` on a schedule (daily is enough) so the Vault bundle follows renewals, or have the server pull the certificate itself with the [KrakenKey CLI](https://krakenkey.io/docs/cli/).

To rotate the private key, run `terraform apply -var key_version=2`. Terraform stores a new key, builds a new CSR and issues a new certificate. The old certificate stays valid in KrakenKey until it expires.

`terraform destroy` removes everything from state but keeps the certificate valid in KrakenKey. Set `revoke_on_destroy = true` on `krakenkey_certificate` to revoke it instead.
