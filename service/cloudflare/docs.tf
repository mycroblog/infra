# mycroblog/my のドキュメントサイト。Worker my-docs 自体は mycroblog/my の GitHub Actions (environment docs-site) が
# wrangler でデプロイし、このリポジトリではドメインと DNS のみを管理する。
# Custom Domain は Worker が存在しないと作成できないため、先に my-docs をデプロイしておくこと。

# apex を Worker に紐づける。DNS レコード (A/AAAA) と証明書は Cloudflare が自動で作成する。
# environment は非推奨の属性で、省略すると production になる。
resource "cloudflare_workers_custom_domain" "docs" {
  account_id = local.account_id
  zone_id    = local.zone_id
  hostname   = local.domain
  service    = "my-docs"
}

# www.mycroblog.dev は https://mycroblog.dev へリダイレクトする。
# リダイレクトはプロキシ経由でのみ動くため、宛先のない proxied レコードを置く。
resource "cloudflare_dns_record" "www" {
  zone_id = local.zone_id
  type    = "AAAA"
  name    = "www.${local.domain}"
  content = "100::"
  ttl     = 1 # Auto
  proxied = true
}

resource "cloudflare_ruleset" "redirect" {
  zone_id = local.zone_id
  name    = "redirect"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules = [{
    ref         = "www_to_apex"
    description = "www.${local.domain} -> ${local.domain}"
    expression  = "(http.host eq \"www.${local.domain}\")"
    action      = "redirect"
    action_parameters = {
      from_value = {
        status_code           = 301
        preserve_query_string = true
        target_url = {
          expression = "concat(\"https://${local.domain}\", http.request.uri.path)"
        }
      }
    }
  }]
}
