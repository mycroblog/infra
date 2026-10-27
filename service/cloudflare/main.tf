terraform {
  backend "gcs" {
    bucket = "mycroblog-tfstate"
    prefix = "service/cloudflare"
  }
}
