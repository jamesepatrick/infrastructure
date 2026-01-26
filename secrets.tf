# Used in modules
# tflint-ignore: terraform_unused_declarations
data "onepassword_vault" "infrastructure" {
  name = "infrastructure"
}
