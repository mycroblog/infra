# GitHub Actions から OpenTofu を実行するための Workload Identity Federation。
# plan 用 SA は mycroblog/infra の全ての ref (PR 含む) から利用できるため読み取り権限のみ与える。
# apply 用 SA は production environment からのみ利用できる。
# environment 側の deployment branch policy で main ブランチに限定すること。

locals {
  github_repository = "mycroblog/infra"
  # リポジトリ名の変更・再利用対策として ID で照合する
  github_repository_id = "1435572834"
  # immutable subject が有効なため、sub は `repo:<owner>@<owner_id>/<repo>@<repo_id>:...` 形式になる
  github_subject_prefix = "repo:mycroblog@346242925/infra@${local.github_repository_id}"

  tofu_plan_roles = [
    "roles/viewer",
    "roles/iam.securityReviewer",
  ]
  tofu_apply_roles = [
    "roles/owner",
  ]
}

resource "google_project_service" "ci" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub"

  depends_on = [google_project_service.ci]
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository_id == \"${local.github_repository_id}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "tofu_plan" {
  account_id   = "tofu-plan"
  display_name = "OpenTofu plan (GitHub Actions)"

  depends_on = [google_project_service.ci]
}

resource "google_service_account" "tofu_apply" {
  account_id   = "tofu-apply"
  display_name = "OpenTofu apply (GitHub Actions)"

  depends_on = [google_project_service.ci]
}

resource "google_service_account_iam_member" "tofu_plan_github" {
  service_account_id = google_service_account.tofu_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.github_repository}"
}

resource "google_service_account_iam_member" "tofu_apply_github" {
  service_account_id = google_service_account.tofu_apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${local.github_subject_prefix}:environment:production"
}

resource "google_project_iam_member" "tofu_plan" {
  for_each = toset(local.tofu_plan_roles)

  project = local.project_id
  role    = each.value
  member  = google_service_account.tofu_plan.member
}

resource "google_project_iam_member" "tofu_apply" {
  for_each = toset(local.tofu_apply_roles)

  project = local.project_id
  role    = each.value
  member  = google_service_account.tofu_apply.member
}

# plan は -lock=false で実行するため state の読み取りのみ許可する
resource "google_storage_bucket_iam_member" "tofu_plan_tfstate" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.tofu_plan.member
}

output "github_actions_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github_actions.name
}

output "github_actions_plan_service_account" {
  value = google_service_account.tofu_plan.email
}

output "github_actions_apply_service_account" {
  value = google_service_account.tofu_apply.email
}
