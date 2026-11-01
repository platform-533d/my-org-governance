# Organization-wide settings for the Malaysian organization, managed from its
# Management account in the Control Tower home region, where Identity Center also lives.
# Credentials come from the environment (AWS_PROFILE=my-adm-mgmt locally).
provider "aws" {
  region              = "ap-southeast-5"
  allowed_account_ids = ["277576839910"]

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Repo      = "my-org-governance"
    }
  }
}
