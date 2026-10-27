# apply ジョブが使う environment。GCP の apply 用 SA はこの environment からのみ利用できる。
import {
  to = github_repository_environment.production
  id = "infra:production"
}

import {
  to = github_repository_environment_deployment_policy.production_main
  id = "infra:production:64520606"
}

resource "github_repository_environment" "production" {
  repository  = github_repository.infra.name
  environment = "production"

  can_admins_bypass   = false
  prevent_self_review = false

  reviewers {
    users = [29084] # rosylilly
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "production_main" {
  repository     = github_repository.infra.name
  environment    = github_repository_environment.production.environment
  branch_pattern = "main"
}
