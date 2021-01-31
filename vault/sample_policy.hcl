path "secret/data/hoge/account" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/data/fuga/*" {
  capabilities = ["read", "list"]
}

path "secret/data/deny/*" {
  capabilities = ["deny"]
}
