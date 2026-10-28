# Organization のメンバーとチームを members.yaml から同期する。
locals {
  directory = yamldecode(file("${path.module}/../../members.yaml"))

  team_memberships = merge([
    for login, member in local.directory.members : {
      for list in member.lists : "${list}/${login}" => {
        team     = list
        username = login
        # Organization の owner はチームでは常に maintainer として扱われる
        role = member.github_role == "admin" ? "maintainer" : "member"
      }
    }
  ]...)
}

import {
  to = github_membership.member["rosylilly"]
  id = "mycroblog:rosylilly"
}

resource "github_membership" "member" {
  for_each = local.directory.members

  username = each.key
  role     = each.value.github_role
}

resource "github_team" "list" {
  for_each = toset(local.directory.lists)

  name    = each.key
  privacy = "closed"
}

resource "github_team_membership" "member" {
  for_each = local.team_memberships

  team_id  = github_team.list[each.value.team].id
  username = github_membership.member[each.value.username].username
  role     = each.value.role
}
