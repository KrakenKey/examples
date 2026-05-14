# KrakenKey Examples

Example workflows and integrations for [KrakenKey](https://krakenkey.io).

## GitHub Actions

| Workflow | Description |
|----------|-------------|
| [Issue a certificate](.github/workflows/issue.yml) | Issue a new TLS certificate for a domain |
| [Download a certificate](.github/workflows/download.yml) | Download an existing certificate by ID |
| [Renew a certificate](.github/workflows/renew.yml) | Renew a certificate that is near expiry |
| [Deploy to Nginx](.github/workflows/deploy-nginx.yml) | Issue a certificate and deploy it to an Nginx server |

## Setup

1. [Create a KrakenKey API key](https://app.krakenkey.io)
2. Add it as a repository secret named `KRAKENKEY_API_KEY`
3. Copy any workflow into your `.github/workflows/` directory
4. Trigger it via `workflow_dispatch` in the Actions tab or adapt the trigger to your needs

## Inputs Reference

See the full [cert-action documentation](https://github.com/KrakenKey/cert-action) for all available inputs and outputs.
