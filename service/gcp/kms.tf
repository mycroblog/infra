# OpenTofu の state / plan 暗号化 (gcp_kms key provider) に使う鍵。
# 鍵を失うと state を復号できなくなるため削除しないこと。
resource "google_project_service" "kms" {
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = false
}

resource "google_kms_key_ring" "tofu" {
  name     = "tofu"
  location = local.region

  depends_on = [google_project_service.kms]
}

resource "google_kms_crypto_key" "tfstate" {
  name            = "tfstate"
  key_ring        = google_kms_key_ring.tofu.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 日

  lifecycle {
    prevent_destroy = true
  }
}

# key provider は実行ごとにデータ鍵を生成して KMS で暗号化するため、plan でも暗号化・復号の両方が必要
resource "google_kms_crypto_key_iam_member" "tfstate" {
  for_each = {
    tofu_plan  = google_service_account.tofu_plan.member
    tofu_apply = google_service_account.tofu_apply.member
  }

  crypto_key_id = google_kms_crypto_key.tfstate.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value
}

output "tfstate_kms_key" {
  value = google_kms_crypto_key.tfstate.id
}
