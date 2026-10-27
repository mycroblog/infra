# GitHub Actions (.github/workflows/tofu.yml) が参照する Variables。いずれも秘密情報ではない。
locals {
  actions_variables = {
    GCP_WORKLOAD_IDENTITY_PROVIDER  = "projects/375650693103/locations/global/workloadIdentityPools/github/providers/github-actions"
    TOFU_GITHUB_PLAN_APP_CLIENT_ID  = "Iv23lixgLeHNWGm7GaUh"
    TOFU_GITHUB_APPLY_APP_CLIENT_ID = "Iv23liGYkDrZGQudTmWV"
  }
}

import {
  for_each = local.actions_variables

  to = github_actions_variable.infra[each.key]
  id = "infra:${each.key}"
}

resource "github_actions_variable" "infra" {
  for_each = local.actions_variables

  repository    = github_repository.infra.name
  variable_name = each.key
  value         = each.value
}
