import {
  to = github_repository.infra
  id = "infra"
}

resource "github_repository" "infra" {
  name       = "infra"
  visibility = "public"

  # 外部から Issue を作成させないため無効にしている
  has_issues      = false
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

# PR の作成を collaborator に限定する。
# provider (6.13.0) が pull_request_creation_policy に未対応のため、apply 時に API で設定している。
# GitHub 上で変更されてもドリフトは検出されない。
# provider が対応したら (integrations/terraform-provider-github#3349) github_repository に移すこと。
resource "terraform_data" "infra_pull_request_creation_policy" {
  triggers_replace = {
    repository = github_repository.infra.full_name
    policy     = "collaborators_only"
  }

  # GITHUB_TOKEN (apply 用 GitHub App のトークン) で実行する
  provisioner "local-exec" {
    command = "gh api --method PATCH repos/${self.triggers_replace.repository} -f pull_request_creation_policy=${self.triggers_replace.policy} --silent"
  }
}
