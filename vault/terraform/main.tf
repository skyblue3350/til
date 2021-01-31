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