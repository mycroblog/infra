import {
  to = github_repository.infra
  id = "infra"
}

resource "github_repository" "infra" {
  name       = "infra"
  visibility = "public"

  has_issues      = true
  has_projects    = true
  has_wiki        = true
  has_discussions = false

  allow_merge_commit     = true
  allow_squash_merge     = true
  allow_rebase_merge     = true
  allow_auto_merge       = false
  allow_update_branch    = false
  delete_branch_on_merge = true

  merge_commit_title          = "MERGE_MESSAGE"
  merge_commit_message        = "PR_TITLE"
  squash_merge_commit_title   = "COMMIT_OR_PR_TITLE"
  squash_merge_commit_message = "COMMIT_MESSAGES"

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_vulnerability_alerts" "infra" {
  repository = github_repository.infra.name
  enabled    = true
}

# vulnerability alerts が有効であることが前提
resource "github_repository_dependabot_security_updates" "infra" {
  repository = github_repository.infra.name
  enabled    = true

  depends_on = [github_repository_vulnerability_alerts.infra]
}
