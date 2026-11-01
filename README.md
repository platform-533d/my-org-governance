# my-org-governance

Organization-wide settings for the 533d **Malaysian** AWS organization, managed from its
Management account (`277576839910`). Control Tower home region and everything here: `ap-southeast-5`.

| File | Manages |
|---|---|
| `identity-readonly.tf` | `my-533d-readonly` user, `ReadOnlyInvestigators` group and `ReadOnlyInvestigation` permission set, assigned to every active account |

Administration is done with the `MY-533d-Admin` IAM user in the management account
(console sign-in or `aws login`); there is no Identity Center admin user.

State: `s3://my-org-governance-tfstate-277576839910/my-org-governance/terraform.tfstate`
(bucket in `ap-southeast-5`, created by `bootstrap/create-state-bucket.sh`).

## Usage

```bash
aws login --profile my-admin --region ap-southeast-5     # sign in as the MY-533d-Admin IAM user
AWS_PROFILE=my-admin ./bootstrap/create-state-bucket.sh  # first time only

# Terraform cannot read `aws login` sessions directly; export the short-lived
# session credentials into this shell only (nothing is written to disk).
eval "$(aws configure export-credentials --profile my-admin --format env)"
export AWS_REGION=ap-southeast-5
terraform init
terraform plan
```

## Read-only user first login

The API cannot send the Identity Center invitation. After the first apply, open
IAM Identity Center (Asia Pacific (Malaysia)) → Users → `my-533d-readonly` and choose
**Send email verification link** or **Reset password**, then set the password and register MFA.
Use a private browser window so the admin session is not reused.
