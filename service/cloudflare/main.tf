terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  backend "gcs" {
    bucket = "mycroblog-tfstate"
    prefix = "service/cloudflare"
  }
}

locals {
  account_id = "994aaaf195ab62477609d5dd730e0b8f"
  zone_id    = "d1efd91243643b316be9e4fa39dbd265"
  domain     = "mycroblog.dev"
}

# API トークンは環境変数 CLOUDFLARE_API_TOKEN で渡す
provider "cloudflare" {}

# Secret Manager の参照に使う
provider "google" {
  project = "mycroblog"
}
