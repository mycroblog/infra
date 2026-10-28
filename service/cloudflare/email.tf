# メーリングリスト。<list>@mycroblog.dev 宛のメールを Email Worker が各メンバーの転送先アドレスへ配送する。
# Email Routing のルールは転送先を 1 件しか持てないため、配送は Worker で行う。
locals {
  directory = yamldecode(file("${path.module}/../../members.yaml"))

  # GitHub login => 転送先アドレス (sensitive)
  member_emails = jsondecode(data.google_secret_manager_secret_version.member_emails.secret_data)

  # リストのアドレス => 所属メンバーの転送先アドレス (sensitive)
  mailing_lists = {
    for list in local.directory.lists : "${list}@${local.domain}" => [
      for login, member in local.directory.members : local.member_emails[login] if contains(member.lists, list)
    ]
  }
}

data "google_secret_manager_secret_version" "member_emails" {
  secret = "member-emails"
}

# 確認済みの既存アドレス。member-emails の rosylilly の値と一致している必要がある。
import {
  to = cloudflare_email_routing_address.member["rosylilly"]
  id = "994aaaf195ab62477609d5dd730e0b8f/b36c15b0ca50464186d969714123723f"
}

# 作成すると確認メールが送られ、本人がリンクを開くまで転送されない
resource "cloudflare_email_routing_address" "member" {
  for_each = toset(keys(local.directory.members))

  account_id = local.account_id
  email      = local.member_emails[each.key]
}

resource "cloudflare_workers_script" "mailing_list" {
  account_id         = local.account_id
  script_name        = "mailing-list"
  main_module        = "mailing-list.js"
  content            = file("${path.module}/workers/mailing-list.js")
  compatibility_date = "2026-10-01"

  bindings = [{
    type = "secret_text"
    name = "MAILING_LISTS"
    text = jsonencode(local.mailing_lists)
  }]

  observability = {
    enabled = true
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for member in local.directory.members : alltrue([for list in member.lists : contains(local.directory.lists, list)])
      ])
      error_message = "members.yaml のメンバーが lists にないリストに所属しています。"
    }
  }
}

# Email Worker なので workers.dev では公開しない
resource "cloudflare_workers_script_subdomain" "mailing_list" {
  account_id       = local.account_id
  script_name      = cloudflare_workers_script.mailing_list.script_name
  enabled          = false
  previews_enabled = false
}

resource "cloudflare_email_routing_rule" "mailing_list" {
  for_each = toset(local.directory.lists)

  zone_id = local.zone_id
  name    = "mailing list: ${each.key}"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "${each.key}@${local.domain}"
  }]

  actions = [{
    type  = "worker"
    value = [cloudflare_workers_script.mailing_list.script_name]
  }]
}
