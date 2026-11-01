# State stays in Malaysia: Malaysian management account, ap-southeast-5.
# The bucket is created once by bootstrap/create-state-bucket.sh.
terraform {
  backend "s3" {
    bucket       = "my-org-governance-tfstate-277576839910"
    key          = "my-org-governance/terraform.tfstate"
    region       = "ap-southeast-5"
    encrypt      = true
    use_lockfile = true
  }
}
