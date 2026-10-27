terraform {
  backend "gcs" {
    bucket = "mycroblog-tfstate"
    prefix = "app/nightly.mycroblog.dev"
  }
}
