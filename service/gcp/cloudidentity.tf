# Cloud Identity Group (gcp-*-admins@mycroblog.dev など) のメンバー管理に使う
resource "google_project_service" "cloudidentity" {
  service            = "cloudidentity.googleapis.com"
  disable_on_destroy = false
}
