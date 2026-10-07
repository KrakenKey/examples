terraform {
  required_version = ">= 1.11"

  required_providers {
    krakenkey = {
      source  = "krakenkey/krakenkey"
      version = "~> 0.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# Reads the API key from KK_API_KEY.
provider "krakenkey" {}

# Reads CLOUDFLARE_API_TOKEN. The token needs DNS edit on the zone.
provider "cloudflare" {}

# Reads VAULT_ADDR and VAULT_TOKEN.
provider "vault" {}
