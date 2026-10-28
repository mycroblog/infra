# Cloud Identity Group のメンバーを members.yaml から同期する。
# Group 自体は Organization の初期設定で作成済みのため、メンバーシップのみ管理する。
# tofu-apply にはグループ管理者、tofu-plan にはグループ閲覧者の管理者ロールを Admin コンソールで割り当てている。
locals {
  directory = yamldecode(file("${path.module}/../../members.yaml"))

  # members.yaml のリスト名 => Cloud Identity Group
  cloud_identity_groups = {
    "gcp-billing-admins"      = "groups/049x2ik51bwxsek"
    "gcp-organization-admins" = "groups/04d34og82d9om6n"
  }

  cloud_identity_group_memberships = merge([
    for login, member in local.directory.members : {
      for list in member.lists : "${list}/${login}" => {
        group   = local.cloud_identity_groups[list]
        account = member.google_account
        roles   = member.github_role == "admin" ? ["OWNER", "MEMBER"] : ["MEMBER"]
      } if contains(keys(local.cloud_identity_groups), list)
    }
  ]...)
}

import {
  to = google_cloud_identity_group_membership.member["gcp-billing-admins/rosylilly"]
  id = "groups/049x2ik51bwxsek/memberships/102665357578877479116"
}

import {
  to = google_cloud_identity_group_membership.member["gcp-organization-admins/rosylilly"]
  id = "groups/04d34og82d9om6n/memberships/102665357578877479116"
}

resource "google_cloud_identity_group_membership" "member" {
  for_each = local.cloud_identity_group_memberships

  group = each.value.group

  preferred_member_key {
    id = each.value.account
  }

  dynamic "roles" {
    for_each = toset(each.value.roles)
    content {
      name = roles.value
    }
  }

  depends_on = [google_project_service.cloudidentity]
}
