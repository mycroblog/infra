terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # state は自身が管理する tfstate バケットに保存している。
  # バケットを作り直す場合は backend をコメントアウトしてローカル state で apply し、
  # その後 `tofu init -migrate-state` で戻すこと。
  backend "gcs" {
    bucket = "mycroblog-tfstate"
    prefix = "service/gcp"
  }
}

locals {
  project_id = "mycroblog"
  region     = "asia-northeast1"
}

provider "google" {
  project = local.project_id
  region  = local.region
}
