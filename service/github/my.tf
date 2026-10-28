# mycroblog/my
import {
  to = github_repository.my
  id = "my"
}

import {
  to = github_repository_ruleset.my_main
  id = "my:25247951"
}

resource "github_repository" "my" {
  name       = "my"
  visibility = "public"

  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_discussions = false

  allow_merge_commit     = true
  allow_squash_merge     = true
  allow_rebase_merge     = true
  allow_auto_merge       = true
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

resource "github_repository_vulnerability_alerts" "my" {
  repository = github_repository.my.name
  enabled    = true
}

resource "github_repository_dependabot_security_updates" "my" {
  repository = github_repository.my.name
  enabled    = false

  depends_on = [github_repository_vulnerability_alerts.my]
}

# main への変更は merge queue 経由のみとし、check の成功を必須にする。
# NOTE: provider は pull_request の require_extra_approval_for_unattributed_changes に未対応。
# ruleset を更新すると既定値に戻る可能性があるため、apply 後に GitHub 上で確認すること。
resource "github_repository_ruleset" "my_main" {
  repository  = github_repository.my.name
  name        = "protect-main"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    actor_id    = 5 # Repository admin
    actor_type  = "RepositoryRole"
    bypass_mode = "pull_request"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      # Organization のメンバーが 1 人のため承認は必須にしない
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_review_thread_resolution = false
      allowed_merge_methods             = ["merge", "squash", "rebase"]
    }

    required_status_checks {
      strict_required_status_checks_policy = false
      do_not_enforce_on_create             = false

      required_check {
        context = "check"
      }
    }

    merge_queue {
      merge_method                      = "MERGE"
      grouping_strategy                 = "ALLGREEN"
      max_entries_to_build              = 2
      min_entries_to_merge              = 1
      max_entries_to_merge              = 5
      min_entries_to_merge_wait_minutes = 1
      check_response_timeout_minutes    = 60
    }
  }
}
