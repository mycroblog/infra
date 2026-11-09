# rc.mycroblog.dev のインスタンス専用のプロジェクト。中身は app/rc.mycroblog.dev で管理する。
#
# ここではプロジェクトの作成、請求先アカウントへの紐付け、組織ポリシーの例外の設定を行う。
# そのため CI の SA には組織と請求先アカウントの権限が必要になる。
# SA 自身はプロジェクト単位の権限しか持たず、これらを自分に付与できないので、組織の管理者が事前に以下を手動で実行すること。
#   gcloud organizations add-iam-policy-binding 293072108464 \
#     --member=serviceAccount:tofu-apply@mycroblog.iam.gserviceaccount.com --role=roles/resourcemanager.projectCreator
#   gcloud organizations add-iam-policy-binding 293072108464 \
#     --member=serviceAccount:tofu-apply@mycroblog.iam.gserviceaccount.com --role=roles/orgpolicy.policyAdmin
#   gcloud organizations add-iam-policy-binding 293072108464 \
#     --member=serviceAccount:tofu-plan@mycroblog.iam.gserviceaccount.com --role=roles/orgpolicy.policyViewer
#   gcloud billing accounts add-iam-policy-binding 013C46-7FFDEE-81C265 \
#     --member=serviceAccount:tofu-apply@mycroblog.iam.gserviceaccount.com --role=roles/billing.user

locals {
  organization_id = "293072108464" # mycroblog.dev
  billing_account = "013C46-7FFDEE-81C265"

  rc_project_id = "mycroblog-rc-5996"

  # docs/operations/deploy-cloud-run.md (mycroblog/my) の「Enable the APIs」に、
  # KEK 用の Cloud KMS、monitoring-gcp 用の Cloud Monitoring、billing-gcp 用の BigQuery を加えたもの。
  # ingress に load balancer を使わないため compute.googleapis.com は有効にしない。
  rc_services = [
    "bigquery.googleapis.com", # 料金の取り込みのクエリを rc の割り当てで実行する
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudtasks.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ]
}

# SA の API 呼び出しは mycroblog の割り当てで行われるため、使う API を mycroblog 側でも有効にしておく。
#   - cloudbilling, orgpolicy: プロジェクトの請求先の設定と組織ポリシーの操作
#   - pubsub: app/rc.mycroblog.dev の topic の読み取り。Pub/Sub は呼び出し元の SA のプロジェクトを割り当て先にする
resource "google_project_service" "rc_management" {
  for_each = toset([
    "cloudbilling.googleapis.com",
    "orgpolicy.googleapis.com",
    "pubsub.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

resource "google_project" "rc" {
  project_id      = local.rc_project_id
  name            = "rc.mycroblog.dev"
  org_id          = local.organization_id
  billing_account = local.billing_account

  # KEK (Cloud KMS) やメディアを失わないよう、削除できなくしておく
  deletion_policy = "PREVENT"

  depends_on = [google_project_service.rc_management]
}

resource "google_project_service" "rc" {
  for_each = toset(local.rc_services)

  project            = google_project.rc.project_id
  service            = each.value
  disable_on_destroy = false
}

# 組織では iam.allowedPolicyMemberDomains で自組織のアカウントにしか権限を付与できない。
# しかし app-gcp-cloud-run モジュール (mycroblog/my) は、公開のために Cloud Run サービスの roles/run.invoker を allUsers に付与する。
# この付与ができるように、rc プロジェクトでだけ制約を解除する。
resource "google_org_policy_policy" "rc_allowed_policy_member_domains" {
  name   = "projects/${google_project.rc.project_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "projects/${google_project.rc.project_id}"

  spec {
    rules {
      allow_all = "TRUE"
    }
  }

  depends_on = [google_project_service.rc_management]
}

# app/rc.mycroblog.dev も CI の plan / apply 用 SA で実行するため、mycroblog と同じロールを付与する
resource "google_project_iam_member" "rc_tofu_plan" {
  for_each = toset(local.tofu_plan_roles)

  project = google_project.rc.project_id
  role    = each.value
  member  = google_service_account.tofu_plan.member
}

resource "google_project_iam_member" "rc_tofu_apply" {
  for_each = toset(local.tofu_apply_roles)

  project = google_project.rc.project_id
  role    = each.value
  member  = google_service_account.tofu_apply.member
}

# 人による運用 (upgrade.sh / console.sh、ログの閲覧、障害対応) は組織の管理者が行う
resource "google_project_iam_member" "rc_operators" {
  project = google_project.rc.project_id
  role    = "roles/owner"
  member  = "group:gcp-organization-admins@mycroblog.dev"
}

output "rc_project_id" {
  value = google_project.rc.project_id
}
