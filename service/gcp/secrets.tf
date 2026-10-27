# GitHub Actions で利用する外部サービスの認証情報。
# 値は state に残さないよう OpenTofu では管理せず、以下で手動登録する。
#   gcloud secrets versions add <secret_id> --data-file=-
# plan 用には読み取り専用の認証情報を登録すること。

locals {
  ci_secrets = {
    "cloudflare-api-token-plan"    = google_service_account.tofu_plan.member
    "cloudflare-api-token-apply"   = google_service_account.tofu_apply.member
    "github-app-private-key-plan"  = google_service_account.tofu_plan.member
    "github-app-private-key-apply" = google_service_account.tofu_apply.member
  }
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "ci" {
  for_each = local.ci_secrets

  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "ci" {
  for_each = local.ci_secrets

  secret_id = google_secret_manager_secret.ci[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}
