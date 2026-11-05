# Resend からメールを送信するための DNS レコード。
# 値は Resend のドメイン設定の画面に表示されたもの。
locals {
  resend_dns_records = {
    dkim = {
      type    = "TXT"
      name    = "resend._domainkey"
      content = "\"p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCwEIPMb+KB+H5gJbYpG3pO2PjK85BBA9p8pXtPEfpr47E+xLNQwklOi9+mKwX5kINJMixVZAcPEexsqWwO+zEDrecCKI0osqifHumozmNGFezwrq+quZXkXAGVX6Hq++KqQE5n9jhUtgEGK0FdyWZWWm4WZX79dR8eT1/JuIAZVwIDAQAB\""
    }
    rsend = {
      type    = "CNAME"
      name    = "rsend"
      content = "rsend-apne1.forge.rmta.net"
    }
    send = {
      type    = "CNAME"
      name    = "send"
      content = "send.forge.rmta.net"
    }
    dmarc = {
      type    = "TXT"
      name    = "_dmarc"
      content = "\"v=DMARC1; p=none;\""
    }
  }
}

resource "cloudflare_dns_record" "resend" {
  for_each = local.resend_dns_records

  zone_id = local.zone_id
  type    = each.value.type
  name    = "${each.value.name}.${local.domain}"
  content = each.value.content
  ttl     = 1 # Auto
  proxied = false
}
