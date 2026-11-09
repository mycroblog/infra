# Cloud Billing の BigQuery エクスポート (標準の使用料金) の書き出し先。
# エクスポートは請求先アカウント単位で 1 つなので、特定のインスタンスのプロジェクトではなく mycroblog に置き、
# 各インスタンスは app/* で billing-gcp (mycroblog/my) により閲覧権限を得て、自分のプロジェクトの分だけを取り込む。
#
# エクスポートの有効化は API がないため、apply 後にコンソールで行う (請求先アカウントの Billing Account Costs Manager 以上が必要)。
#   お支払い > 課金データのエクスポート > BigQuery Export > 標準の使用料金 > このデータセットを選ぶ
# テーブル gcp_billing_export_v1_013C46_7FFDEE_81C265 は数時間から 1 日後に作られる。
# 単一リージョンのため、データは有効にした日からになる。ロケーションは後から変えられない。

resource "google_project_service" "bigquery" {
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_bigquery_dataset" "billing_export" {
  dataset_id  = "billing_export"
  location    = "asia-southeast1"
  description = "Cloud Billing export (standard usage cost) of the billing account, read by the instances' cost import."

  # 期限切れや削除された行は戻らないため
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.bigquery]
}

output "billing_export_dataset" {
  value = "${local.project_id}.${google_bigquery_dataset.billing_export.dataset_id}"
}
