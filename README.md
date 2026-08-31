# KrakenKey Examples

Example workflows and integrations for [KrakenKey](https://krakenkey.io), automated TLS certificate management via ACME DNS-01. Copy any workflow into your own repository's `.github/workflows/` directory and adapt it.

These are not just documentation: the scheduled workflows in this repo run for real against `api.krakenkey.io`, using a dedicated demo account and the certificate for `examples.krakenkey.io`.

## Workflows

| Workflow | Trigger | What it shows |
|----------|---------|---------------|
| [Issue Certificate](.github/workflows/issue.yml) | manual | Issue a new certificate with a chosen domain, optional SANs and key type, then collect cert, key and CSR as artifacts |
| [Download Certificate](.github/workflows/download.yml) | manual, plus weekly schedule | Fetch an existing certificate by ID, verify it with OpenSSL and upload it as an artifact |
| [Renew Certificate](.github/workflows/renew.yml) | manual, plus daily schedule | Renew a certificate by ID. Safe to run on a schedule: renewal is a no-op until the certificate is near expiry |
| [Deploy to Nginx](.github/workflows/deploy-nginx.yml) | manual | Issue a certificate, copy it to a server over SSH and reload Nginx |

## Setup

1. [Create a KrakenKey API key](https://app.krakenkey.io/dashboard/api-keys) and add it as a repository secret named `KRAKENKEY_API_KEY`.
2. For the scheduled renew and download runs, add a repository variable `KRAKENKEY_CERT_ID` with the ID of the certificate to operate on. Manual runs take the ID as an input instead.
3. The Nginx example additionally needs `SSH_USERNAME` and `SSH_PRIVATE_KEY` secrets for the target server.

## Version pinning

The examples pin `KrakenKey/cert-action` to a release tag (currently `v1.1.0`), which is what you should do in your own workflows. The one exception is `renew.yml`, which intentionally tracks `@main`: its daily scheduled run doubles as KrakenKey's own integration canary, exercising the action, the CLI and the production API end to end every day.

## Reference

See the [cert-action documentation](https://github.com/KrakenKey/cert-action) for all available inputs and outputs, and the [KrakenKey CLI](https://github.com/KrakenKey/cli) if you prefer scripting against the API directly.
