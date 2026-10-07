# KrakenKey Examples

Example workflows and Terraform configurations for [KrakenKey](https://krakenkey.io), automated TLS certificate management via ACME DNS-01. Copy what you need into your own repository and adapt it.

These are not just documentation: the scheduled workflows in this repo run for real against `api.krakenkey.io`, using a dedicated demo account and the certificate for `examples.krakenkey.io`.

## GitHub Actions

| Workflow | Trigger | What it shows |
|----------|---------|---------------|
| [Issue Certificate](.github/workflows/issue.yml) | manual | Issue a new certificate with a chosen domain, optional SANs and key type, then collect the certificate, chain and CSR as artifacts. The private key is never uploaded |
| [Download Certificate](.github/workflows/download.yml) | manual, plus daily schedule | Fetch an existing certificate by ID, verify it and its chain with OpenSSL and upload it as an artifact. The daily run is a read-only canary |
| [Renew Certificate](.github/workflows/renew.yml) | manual, plus daily schedule | Renew a certificate by ID. Scheduled runs use `if-due`, so they only renew inside the plan's renewal window; once a week the canary renews unconditionally |
| [Nginx - Issue Certificate](.github/workflows/nginx-issue.yml) | manual, once | Issue a certificate and install the key and full chain on a server over SSH |
| [Nginx - Renew and Deploy](.github/workflows/nginx-renew.yml) | manual (daily in your repo) | Renew with `if-due` and deploy over SSH only when the server serves an older certificate. The schedule is commented out here because this repo has no server |

## On the server

| Example | What it shows |
|---------|---------------|
| [`host/`](host/) | The server runs the CLI itself: a renewal script and systemd timer for nginx or HAProxy, so the private key never leaves the host. [Host Renewal Test](.github/workflows/host-test.yml) checks the script against a fake CLI on every change |

## Terraform

The [`krakenkey/krakenkey`](https://registry.terraform.io/providers/KrakenKey/krakenkey/latest) provider manages domains, certificates, endpoint monitoring and alert channels. See the [Terraform guide](https://krakenkey.io/docs/integrations/terraform/) for a walkthrough.

| Configuration | What it shows |
|---------------|---------------|
| [`terraform/complete`](terraform/complete/) | A domain, its DNS records in Cloudflare, verification, a certificate whose private key goes to Vault without ever reaching Terraform state, a deploy bundle that follows renewals, endpoint monitoring and a Slack alert channel |
| [`terraform/canary`](terraform/canary/) | A read-only check of an existing certificate with the data source: fails if it isn't issued, expires within 14 days, or has a broken chain. [Terraform Canary](.github/workflows/terraform-canary.yml) runs it daily |

[Terraform Validate](.github/workflows/terraform-validate.yml) runs `fmt`, `init` and `validate` on both configurations for every pull request.

## Setup

1. [Create a KrakenKey API key](https://app.krakenkey.io/dashboard/api-keys) and add it as a repository secret named `KRAKENKEY_API_KEY`.
2. For the scheduled runs, add a repository variable `KRAKENKEY_CERT_ID` with the ID of the certificate to operate on. Manual runs take the ID as an input instead.
3. Optionally add a second key with only the `certs:read` scope as `KRAKENKEY_READONLY_API_KEY`. The Terraform canary uses it when present, so the daily check can't change anything.
4. The Nginx workflows additionally need a `DEPLOY_SSH_KEY` secret and `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS` and `TLS_NAME` variables; the comments at the top of each workflow list them.

The GitHub Action can also authenticate with GitHub OIDC instead of a stored key: leave `api-key` empty, grant `id-token: write`, and trust the repository in KrakenKey. See the [cert-action documentation](https://github.com/KrakenKey/cert-action#without-a-stored-api-key-github-oidc).

## Version pinning

The examples pin `KrakenKey/cert-action` to a release tag (currently `v1.4.0`) and the Terraform provider to `~> 0.1`, which is what you should do in your own repositories. The one exception is `renew.yml`, which intentionally tracks `@main`: its scheduled runs double as KrakenKey's own integration canary for the renewal path, while the daily download and Terraform runs cover the read path.

## Reference

- [cert-action](https://github.com/KrakenKey/cert-action): all inputs and outputs
- [Terraform provider docs](https://registry.terraform.io/providers/KrakenKey/krakenkey/latest/docs)
- [KrakenKey CLI](https://github.com/KrakenKey/cli), if you prefer scripting against the API directly

## License

[MIT No Attribution](LICENSE). Copy any workflow or configuration into your own repository without keeping a notice.
