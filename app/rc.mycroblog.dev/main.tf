# rc.mycroblog.dev: リリース候補 (RC) を継続的に動かすインスタンス。
# mycroblog/my の deploy/opentofu/examples/gcp-cloud-run-neon をもとに、以下を変えている。
#   - DB: Neon を db-neon で作る (Free プラン)
#   - KEK: Cloud KMS に置く
#   - 入口: Cloudflare の proxy + Cloud Run の domain mapping
#   - メディア: rc-media.mycroblog.dev から Cloudflare のキャッシュ越しに配信する
#   - 監視: monitoring-gcp を入れる
# 手順は mycroblog/my の docs/operations/deploy-cloud-run.md を参照。
#
# モジュールの ref と image は同じリリースに揃えること。
# image は既存のサービスとジョブには反映されず、更新は upgrade.sh で行う。

terraform {
  required_version = ">= 1.11"

  required_providers {
    # mycroblog/my のモジュールが < 8.0 に固定しているため、他のディレクトリ (~> 8.0) とは揃えていない
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    # db-neon が完全一致で固定している
    neon = {
      source  = "kislerdm/neon"
      version = "0.18.0"
    }
  }

  backend "gcs" {
    bucket = "mycroblog-tfstate"
    prefix = "app/rc.mycroblog.dev"
  }
}

locals {
  project_id = "mycroblog-rc-5996" # service/gcp/rc.tf で作成
  region     = "asia-southeast1"   # Neon (aws-ap-southeast-1) の近く

  host       = "rc.mycroblog.dev"
  media_host = "rc-media.mycroblog.dev" # Universal SSL の対象になるよう 1 階層にしている

  # 作成時のイメージ。以降は upgrade.sh が変える
  image = "ghcr.io/mycroblog/my:0.1.0-rc.5@sha256:cf47c60218cb70e2b9305da41d20e6083885dbfa52336f7870ddb59940330a79"

  cloudflare_zone_id = "d1efd91243643b316be9e4fa39dbd265" # mycroblog.dev
  neon_org_id        = "org-summer-tree-22909412"
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# API トークンは環境変数 CLOUDFLARE_API_TOKEN で渡す
provider "cloudflare" {}

# API キーは環境変数 NEON_API_KEY で渡す
provider "neon" {}

variable "console_enabled" {
  description = "console ジョブを作る。使う間だけ -var console_enabled=true で apply する"
  type        = bool
  default     = false
}

# Cloudflare から来たリクエストであることを示すヘッダーの値。
# provider に write-only の形がないため、どう渡しても値は state に入る (state は KMS で暗号化している)。
# そのため OpenTofu で生成し、secrets モジュールからサーバー用の Secret にも書き込む。
resource "random_password" "origin_secret" {
  length  = 64
  special = false
}

module "secrets" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/secrets-gcp-secret-manager?ref=v0.1.0-rc.5&depth=1"

  project_id         = local.project_id
  secrets            = { MY_VAPID_PRIVATE_KEY = "my-vapid-key" }
  generate_p256_keys = ["MY_VAPID_PRIVATE_KEY"]
  referenced = {
    database_url        = "my-database-url"
    database_url_pooled = "my-database-url-pooled"
    smtp_password       = "my-smtp-password" # Resend の API キー。手動で登録する
    origin_secret       = "my-origin-secret"
  }
  write_keys = ["database_url", "database_url_pooled", "origin_secret"]
  write_values = {
    database_url        = module.db.connection_uri
    database_url_pooled = module.db.connection_uri_pooler
    origin_secret       = random_password.origin_secret.result
  }
}

module "kek" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/kek-gcp-kms?ref=v0.1.0-rc.5&depth=1"

  project_id = local.project_id
  location   = local.region
}

# パスワードが state に入る。provider は unmaintained (モジュールの README 参照)
module "db" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/db-neon?ref=v0.1.0-rc.5&depth=1"

  org_id               = local.neon_org_id
  region_id            = "aws-ap-southeast-1"
  url_secret_id        = module.secrets.ids["database_url"]
  pooled_url_secret_id = module.secrets.ids["database_url_pooled"]
}

# Neon の Free プランは月 100 CU-h まで。毎分の tick では compute が止まらず使い切る。
# uptime check でも DB を起こすため、両方で枠に収まるよう 20 分ごとにしている (定期ジョブは最大 20 分遅れる)
module "queue" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/queue-gcp-cloud-tasks?ref=v0.1.0-rc.5&depth=1"

  project_id    = local.project_id
  region        = local.region
  tick_schedule = "*/20 * * * *"
}

module "blob" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/blob-gcp-gcs?ref=v0.1.0-rc.5&depth=1"

  project_id  = local.project_id
  bucket_name = "${local.project_id}-media"
  location    = local.region
}

module "stream" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/stream-gcp-pubsub?ref=v0.1.0-rc.5&depth=1"

  project_id = local.project_id
}

# Resend の SMTP。mycroblog.dev は service/cloudflare/dns.tf で Resend のドメイン認証を済ませている
module "mail" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/mail-smtp?ref=v0.1.0-rc.5&depth=1"

  from               = "noreply@mycroblog.dev"
  host               = "smtp.resend.com"
  port               = 587
  username           = "resend"
  password_secret_id = module.secrets.ids["smtp_password"]
}

# Cloud Run は Host でルーティングする。Cloudflare で Host を書き換えられるのは Enterprise プランだけなので、
# Cloudflare は ghs.googlehosted.com に接続し、各ホストの domain mapping で受ける。
# domain mapping は backends に入れない (誰が接続してくるかは ingress-cloudflare-app が決める)。
# apply する SA (tofu-apply) が Search Console で mycroblog.dev の確認済み所有者になっている必要がある。
module "domain_mapping_app" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/ingress-gcp-domain-mapping?ref=v0.1.0-rc.5&depth=1"

  project_id   = local.project_id
  region       = local.region
  host         = local.host
  service_name = module.app.service_name
}

module "domain_mapping_media" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/ingress-gcp-domain-mapping?ref=v0.1.0-rc.5&depth=1"

  project_id   = local.project_id
  region       = local.region
  host         = local.media_host
  service_name = module.app.service_name
}

# domain mapping の証明書は、proxied = false で CNAME (ghs.googlehosted.com) のまま発行された (2026-11-09)。
# proxy 越しで証明書が更新されるかは確認されていない (有効期限は 2027-02-07)。
# 更新に失敗すると、SSL モードが strict のため Cloudflare が 526 を返す。
# その場合は一時的に false に戻して更新させる。false の間はヘッダーが付かないため、サーバーはヘルスチェック以外を 403 で拒否する。
locals {
  cloudflare_proxied = true
}

# ゾーンには phase ごとに ruleset が 1 つしか作れない。そのため rc-media のルールは extra_rules でこちらの ruleset に入れる
module "media" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/ingress-cloudflare-media?ref=v0.1.0-rc.5&depth=1"

  zone_id         = local.cloudflare_zone_id
  host            = local.media_host
  origin_host     = "ghs.googlehosted.com"
  proxied         = local.cloudflare_proxied
  manage_rulesets = false
}

module "ingress" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/ingress-cloudflare-app?ref=v0.1.0-rc.5&depth=1"

  zone_id          = local.cloudflare_zone_id
  host             = local.host
  origin_host      = "ghs.googlehosted.com"
  proxied          = local.cloudflare_proxied
  origin_secret    = random_password.origin_secret.result
  origin_secret_id = module.secrets.ids["origin_secret"]
  extra_rules      = module.media.rules
}

# モジュールの README は Neon を起こさないよう /healthz を勧めているが、Cloud Run では /healthz が予約されていて、
# Google のフロントエンドが 404 を返す (コンテナに届かない)。そのため DB を起こす /api/v1/instance/health を使う。
# 結果はプロセスで 60 秒キャッシュされる。900s ごとの check でどれだけ Neon が起きているかは、実際の使用量で確認すること
module "monitoring" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/monitoring-gcp?ref=v0.1.0-rc.5&depth=1"

  project_id          = local.project_id
  host                = local.host
  notification_emails = ["ops@mycroblog.dev"]
  uptime_path         = "/api/v1/instance/health"
  # Free プランの 1 GB から余裕を引いた値
  database_size_limit_bytes = 800 * 1000 * 1000
}

# GCP の利用料金の取り込み。Cloud Billing の BigQuery エクスポートは請求先アカウント単位で、
# 書き出し先のデータセットは mycroblog にある (service/gcp/billing.tf)。
# ここではその閲覧権限と、rc でのクエリの実行権限を得て、MY_BILLING_GCP_PROJECTS で rc のプロジェクトの分だけを取り込む。
module "billing" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/billing-gcp?ref=v0.1.0-rc.5&depth=1"

  project_id         = "mycroblog"
  billing_account_id = "013C46-7FFDEE-81C265"
  create_dataset     = false
  # クエリは rc で実行し、スキャン量も rc に計上する
  query_project = local.project_id
}

module "app" {
  source = "git::https://github.com/mycroblog/my.git//deploy/opentofu/modules/app-gcp-cloud-run?ref=v0.1.0-rc.5&depth=1"

  project_id      = local.project_id
  region          = local.region
  image           = local.image
  host            = local.host
  console_enabled = var.console_enabled
  # Cloudflare からの接続はインターネットから来る。run.app の URL も開いたままだが、origin secret のないリクエストはサーバーが拒否する
  service_ingress = "all"

  backends = [
    module.secrets, module.kek, module.db, module.queue, module.blob, module.stream, module.mail, module.monitoring, module.ingress, module.billing,
    { platform = module.media.platform, env = module.media.env },
  ]

  env = {
    # Cloud Run は 32 MiB を超える HTTP/1 リクエストを拒否するため、サーバー側の上限をその下にする
    MY_MEDIA_MAX_AV_BYTES = "31457280"
    # 請求先アカウントには mycroblog などの他のプロジェクトもあるため、rc の分だけを取り込む
    MY_BILLING_GCP_PROJECTS = local.project_id
  }
}

output "console" {
  description = "console.sh に渡す: tofu output -json console | .terraform/modules/app/deploy/opentofu/console.sh <my のコマンド>"
  value       = module.app.console
}

output "service_uri" {
  value = module.app.service_uri
}
