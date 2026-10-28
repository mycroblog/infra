# mycroblog/infra

[![OpenTofu](https://github.com/mycroblog/infra/actions/workflows/tofu.yml/badge.svg?branch=main)](https://github.com/mycroblog/infra/actions/workflows/tofu.yml?query=branch%3Amain)
[![Dependabot](https://img.shields.io/badge/dependabot-enabled-025e8c?logo=dependabot)](.github/dependabot.yml)

mycroblog のインフラを OpenTofu で管理するリポジトリです。

## 構成

| ディレクトリ | 管理対象 |
|---|---|
| `service/gcp` | GCP プロジェクト (tfstate バケット, KMS, CI 用 Workload Identity, Secret Manager, Cloud Identity Group のメンバー) |
| `service/github` | GitHub Organization (リポジトリ設定, ruleset, メンバーとチーム) |
| `service/cloudflare` | Cloudflare (Email Routing によるメーリングリスト) |
| `app/*` | アプリケーションごとのリソース |
| `members.yaml` | メンバーと所属リスト。上記の各サービスに同期される |

- state は GCS バケット `mycroblog-tfstate` に保存し、Cloud KMS で暗号化しています。暗号化設定 (`encryption.tf`) は全ディレクトリで同一内容にしてください (CI で検査しています)。
- 外部サービスの認証情報は GitHub Secrets ではなく GCP Secret Manager に置いています。
- OpenTofu のバージョンは `.tool-versions` で管理しています。

## 変更の流れ

1. ブランチを作って PR を出すと、変更のあったディレクトリで `tofu plan` が実行され、結果が PR にコメントされます。
2. `main` にマージすると `tofu apply` が実行されます。apply は `production` environment の承認が必要です。

PR を作成できるのは collaborator のみで、Issue は無効にしています。

## メンバーの追加

1. 転送先メールアドレスを Secret Manager の `member-emails` に登録します。
   値は全メンバー分の `{"<GitHub login>": "<email>"}` 形式の JSON で、既存のメンバーを含めた全体を新しいバージョンとして登録します。

   ```sh
   gcloud secrets versions access latest --secret=member-emails --project=mycroblog \
     | jq '. + {"<GitHub login>": "<email>"}' \
     | gcloud secrets versions add member-emails --data-file=- --project=mycroblog
   ```

   メールアドレスは公開リポジトリに置かないため、`members.yaml` には書きません。
   登録より先に `members.yaml` を変更すると plan が失敗します。

2. `members.yaml` にメンバーを追加する PR を作ります。

   ```yaml
   members:
     <GitHub login>:
       github_role: member              # admin にすると Organization の owner
       google_account: <name>@mycroblog.dev
       lists:
         - dev
   ```

3. マージして apply すると、以下が行われます。
   - GitHub Organization への招待が送られ、`lists` と同名のチームに追加されます。
   - Cloudflare から転送先アドレスの確認メールが届きます。本人がリンクを開くまで、メーリングリストのメールは転送されません。
   - `lists` に `gcp-billing-admins` / `gcp-organization-admins` があれば、同名の Cloud Identity Group に追加されます。

### メンバーの削除

`members.yaml` から削除してマージすると、Organization・チーム・Cloud Identity Group から外れます。
その後 `member-emails` からも削除してください。Cloudflare の転送先アドレスは apply で削除されます。

### メーリングリストの追加

`members.yaml` の `lists` に追加すると、`<name>@mycroblog.dev` のメーリングリストと同名の GitHub チームが作成されます。
Cloud Identity Group と同期する場合は、`service/gcp/groups.tf` の `cloud_identity_groups` に Group を追加してください。
