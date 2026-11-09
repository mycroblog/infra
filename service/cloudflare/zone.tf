# ゾーン全体に効く設定。rc.mycroblog.dev などの mycroblog (ActivityPub) のインスタンスを Cloudflare の proxy 越しに公開するための前提。
# mycroblog/my の docs/operations/deploy-cloud-run.md の「Cloudflare」を参照。

# Bot Fight Mode は除外ルールを設定できない。そのため /ap/ や /.well-known/ に来る他のサーバーからのリクエストにも
# チャレンジを返してしまい、連合が壊れる。
resource "cloudflare_bot_management" "zone" {
  zone_id    = local.zone_id
  fight_mode = false
}

resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = local.zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# オリジン (Cloud Run の domain mapping, ghs.googlehosted.com) には HTTPS で接続し、証明書も検証する。
# Flexible にすると HTTP で接続するため、オリジンが HTTPS へリダイレクトしてループする。
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = local.zone_id
  setting_id = "ssl"
  value      = "strict"
}
