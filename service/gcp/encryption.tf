# state / plan の暗号化設定。全ルートモジュールに同一内容で配置する (CI で検査)。
# 鍵は service/gcp/kms.tf で管理している。
# key_provider / method の名前を変えると既存の state を復号できなくなるため変更しないこと。
terraform {
  encryption {
    key_provider "gcp_kms" "tfstate" {
      kms_encryption_key = "projects/mycroblog/locations/asia-northeast1/keyRings/tofu/cryptoKeys/tfstate"
      key_length         = 32
    }

    method "aes_gcm" "tfstate" {
      keys = key_provider.gcp_kms.tfstate
    }

    # 平文の state からの移行用。全 state の暗号化後に削除する
    method "unencrypted" "migrate" {}

    state {
      method = method.aes_gcm.tfstate

      fallback {
        method = method.unencrypted.migrate
      }
    }

    plan {
      method = method.aes_gcm.tfstate

      fallback {
        method = method.unencrypted.migrate
      }
    }
  }
}
