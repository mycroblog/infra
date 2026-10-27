# main への変更は PR 経由のみとし、CI (plan) の成功を必須にする。
resource "github_repository_ruleset" "main" {
  repository  = github_repository.infra.name
  name        = "main"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      # Organization のメンバーが 1 人のため承認は必須にしない
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = false
      required_review_thread_resolution = false
    }

    required_status_checks {
      strict_required_status_checks_policy = true

      required_check {
        context        = "ci"
        integration_id = 15368 # GitHub Actions
      }
    }
  }
}
