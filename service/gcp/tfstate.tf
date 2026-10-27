resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# 各ディレクトリの Remote State を保持するバケット。
# prefix はリポジトリ内のディレクトリパスと揃える (例: service/github, app/nightly.mycroblog.dev)。
resource "google_storage_bucket" "tfstate" {
  name     = "mycroblog-tfstate"
  location = local.region

  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # 古い世代は 10 世代まで保持
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.storage]
}

output "tfstate_bucket" {
  value = google_storage_bucket.tfstate.name
}
