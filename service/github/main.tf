terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "mycroblog-tfstate"
    prefix = "service/github"
  }
}

provider "github" {
  owner = "mycroblog"
}
