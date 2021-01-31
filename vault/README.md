# Vault

## Vault Storage
以下ドキュメントから適当に選ぶ。
今回はメモリ上で動かす `inmem` を試す。

- [Storage Backends - Configuration | Vault by HashiCorp](https://www.vaultproject.io/docs/configuration/storage)
  - [In-Memory | Vault by HashiCorp](https://www.vaultproject.io/docs/configuration/storage/in-memory)

## 環境構築

### Vault server

docker-compose.yaml は以下。
```
version: "3"

services:
  vault:
    image: vault:1.6.2
    ports:
      - 8200:8200
```

設定値メモ。

```
              Api Address: http://0.0.0.0:8200
                      Cgo: disabled
          Cluster Address: https://0.0.0.0:8201
               Go Version: go1.15.7
               Listener 1: tcp (addr: "0.0.0.0:8200", cluster address: "0.0.0.0:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
                Log Level: info
                    Mlock: supported: true, enabled: false
            Recovery Mode: false
                  Storage: inmem
                  Version: Vault v1.6.2
```

### Vault cli

wget で落として適当にパスを通しておく

```
wget https://releases.hashicorp.com/vault/1.6.2/vault_1.6.2_linux_amd64.zip
unzip vault_1.6.2_linux_amd64.zip
chmod +x ./vault
export PATH=$(pwd):$PATH

vault version
Vault v1.6.2 (be65a227ef2e80f8588b3b13584b5c0d9238c1d7)
```

### ログイン周り

8200番でWeb UIが上がってるので適当に見てみる。
ログイン時のトークンは以下。

```
docker-compose logs | grep "Root Token"
vault_1  | Root Token: s.hogehogehoge
```

cliでアクセスする時は事前に向き先を適当なものに変更する
```
export VAULT_ADDR=http://127.0.0.1
vault login
(token): [入力]
```

### token について

root token は基本的に構築以外では使わず運用時は適宜 token を生成して利用する。
vault token は root token を除き全てに TTL が設定されているので定期的に作り直す必要がありセキュア（デフォルト32日設定、延長可能）。

- [Tokens | Vault by HashiCorp](https://www.vaultproject.io/docs/concepts/tokens)

任意の token の期限は以下で確認できる

```
vault token lookup s.hogehogehoge
Key                 Value
---                 -----
accessor            Bw5NxcBTwL7yVALJ8iEcQEUU
creation_time       1612057936
creation_ttl        0s
display_name        root
entity_id           n/a
expire_time         <nil>
explicit_max_ttl    0s
id                  s.hogehogehoge
meta                <nil>
num_uses            0
orphan              true
path                auth/token/root
policies            [root]
ttl                 0s
type                service
```

試しに5分のroot tokenを作ってみる

```
vault token create -period 5m
Key                  Value
---                  -----
token                s.CfWZThZHBzd4BTyis2HFMg0c
token_accessor       SrMYhMKsj6DtKEYFfPIYDMvh
token_duration       5m
token_renewable      true
token_policies       ["root"]
identity_policies    []
policies             ["root"]

vault token lookup s.CfWZThZHBzd4BTyis2HFMg0c
Key                 Value
---                 -----
accessor            SrMYhMKsj6DtKEYFfPIYDMvh
creation_time       1612061110
creation_ttl        5m
display_name        token
entity_id           n/a
expire_time         2021-01-31T02:50:10.7465194Z
explicit_max_ttl    0s
id                  s.CfWZThZHBzd4BTyis2HFMg0c
issue_time          2021-01-31T02:45:10.7465227Z
meta                <nil>
num_uses            0
orphan              false
path                auth/token/create
period              5m
policies            [root]
renewable           true
ttl                 4m39s
type                service
```

期限が切れると bad token となる。

```
date
Sun Jan 31 11:50:19 JST 2021

vault token lookup s.CfWZThZHBzd4BTyis2HFMg0c
Error looking up token: Error making API request.

URL: POST http://127.0.0.1:8200/v1/auth/token/lookup
Code: 403. Errors:

* bad token
```

### policy
任意のパスに対して権限を設定できる。

```bash
vault write sys/policy/sample policy=@sample_policy.hcl
```

適当なデータを用意する。

```bash
vault kv put secret/hoge/account id=test password=hoge
vault kv put secret/fuga/account id=test password=fuga
vault kv put secret/deny/account id=test password=deny
vault kv put secret/foo/account id=test password=foo
```

secret engine v1/v2 で仕様が違うので以下を参考にして適宜ポリシーを設定する。

- [KV - Secrets Engines | Vault by HashiCorp](https://www.vaultproject.io/docs/secrets/kv/kv-v2)

```hcl
path "secret/data/hoge/account" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/data/fuga/*" {
  capabilities = ["read", "list"]
}

path "secret/data/deny/*" {
  capabilities = ["deny"]
}
```

書き込む

```bash
vault write sys/policy/sample policy=@sample_policy.hcl
```

このポリシーに準拠した token を作成する。

```bash
vault token create -policy sample
Key                  Value
---                  -----
token                s.uVpmp021070FSf71iFKE3Msv
token_accessor       2MYaeFcPxCwP4n6nGnUgTqSz
token_duration       768h
token_renewable      true
token_policies       ["default" "sample"]
identity_policies    []
policies             ["default" "sample"]
export VAULT_TOKEN=s.uVpmp021070FSf71iFKE3Msv
```

hoge 以下は権限がフル。

```
vault kv get -field=password secret/hoge/account
hoge
```

fuga 以下は取得だけ。

```
vault kv get -field=password secret/fuga/account
fuga
```

deny はすべて禁止。

```
vault kv get -field=password secret/deny/account
Error reading secret/data/deny/account: Error making API request.

URL: GET http://127.0.0.1:8200/v1/secret/data/deny/account
Code: 403. Errors:

* 1 error occurred:
        * permission denied
```

権限が設定されていない場合も同じ。

```
vault kv get -field=password secret/foo/account
Error reading secret/data/foo/account: Error making API request.

URL: GET http://127.0.0.1:8200/v1/secret/data/foo/account
Code: 403. Errors:

* 1 error occurred:
        * permission denied
```

## Terraform 連携

Terraform の Vault provider を使えば Terraform で state を管理できる
- [Docs overview | hashicorp/vault | Terraform Registry](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)

以下例

```terraform
provider "vault" {}

resource "vault_generic_secret" "sample_password" {
  path = "secret/sample"
  data_json = file("sample.json")
}

resource "vault_generic_secret" "example_password" {
  path = "secret/example"
  data_json = <<EOS
  {
      "id": "example",
      "password": "pass"
  }
  EOS
}
```