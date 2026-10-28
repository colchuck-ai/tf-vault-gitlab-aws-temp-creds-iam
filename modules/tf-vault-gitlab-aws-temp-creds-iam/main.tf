/**
* # tf-vault-gitlab-aws-temp-creds-iam
* 
* The purpose of this module is to create vault resources that allow gitlab cicd pipelines to generate temporary credentials to aws roles.
* 
* ## Usage
* 
* See [referencing a GitLab terraform module registry module](https://docs.gitlab.com/ee/user/packages/terraform_module_registry/#reference-a-terraform-module).
* 
* ```tf
* module "gitlab_cicd_aws_temp_creds_infra_provisioner_read_write" {
*     source = "gitlab.example.com/engineering/tf-vault-gitlab-aws-temp-creds-iam/vault"
*     version = "1.0.0"
* 
*     gitlab_jwt_auth_backend_path = "gitlab_v2"
*     bound_audiences              = ["https://vault.example.com"]
*     bound_claims_project_id      = var.gitlab_infra_project_id
*     bound_claims_ref_type        = "branch"
*     bound_claims_ref_protected   = var.gitlab_infra_project_ref_protected
*     bound_claims_environment     = var.gitlab_infra_project_environment
*     bound_claims_deployment_tier = var.gitlab_infra_project_deployment_tier
*     aws_secret_backend_path      = "aws"
*     aws_role_arn                 = var.aws_infra_provisioner_read_write_role_arn
*   
*     attributes = [
*       "aws-infra-provisioner",
*       "read-write"
*     ]
*   
*     context = module.this.context
* }
* ```
*/

resource "vault_jwt_auth_backend_role" "main" {
  backend           = var.gitlab_jwt_auth_backend_path
  role_type         = "jwt"
  role_name         = module.this.id
  user_claim        = "user_email"
  bound_audiences   = var.bound_audiences
  bound_claims_type = "glob"
  bound_claims = {
    project_id      = var.bound_claims_project_id
    ref_type        = var.bound_claims_ref_type
    ref             = var.bound_claims_ref
    ref_protected   = var.bound_claims_ref_protected
    environment     = var.bound_claims_environment
    deployment_tier = var.bound_claims_deployment_tier
  }
  token_explicit_max_ttl = 300
  token_policies = [
    vault_policy.allow_generate_dynamic_aws_credentials.name
  ]
}

resource "vault_aws_secret_backend_role" "main" {
  backend         = var.aws_secret_backend_path
  name            = module.this.id
  credential_type = "assumed_role"
  role_arns = [
    var.aws_role_arn
  ]
  default_sts_ttl = 900
  max_sts_ttl     = 900
}

data "vault_policy_document" "allow_generate_dynamic_aws_credentials" {
  rule {
    path         = "${var.aws_secret_backend_path}/creds/${vault_aws_secret_backend_role.main.name}"
    capabilities = ["read"]
  }
}

resource "vault_policy" "allow_generate_dynamic_aws_credentials" {
  name = "${module.this.id}-allow-generate-dynamic-aws-credentials"

  policy = data.vault_policy_document.allow_generate_dynamic_aws_credentials.hcl
}