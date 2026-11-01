# my-org-governance

Organization-wide settings for the 533d **Malaysian** AWS organization, managed from its
Management account (`277576839910`). Control Tower home region and everything here: `ap-southeast-5`.

| File | Manages |
|---|---|
| `identity-readonly.tf` | `my-533d-readonly` user, `ReadOnlyInvestigators` group and `ReadOnlyInvestigation` permission set, assigned to every active account |
| `identity-admin.tf` | `MY-533d-Admin` Identity Center user, the single named admin, in Control Tower's `AWSControlTowerAdmins` group (`AWSAdministratorAccess` on the management, Audit and Log Archive accounts) |
| `control-tower-ous.tf` | Registers OUs with Control Tower (`AWSControlTowerBaseline` 5.0): mandatory controls including region deny, auto-enrolment of accounts moved in. Currently: Sandbox |

State: `s3://my-org-governance-tfstate-277576839910/my-org-governance/terraform.tfstate`
(bucket in `ap-southeast-5`, created by `bootstrap/create-state-bucket.sh`).

## Usage

```bash
aws sso login --sso-session my-533d-admin                     # Identity Center user MY-533d-Admin
AWS_PROFILE=my-adm-mgmt ./bootstrap/create-state-bucket.sh  # first time only
AWS_PROFILE=my-adm-mgmt terraform init
AWS_PROFILE=my-adm-mgmt terraform plan
```

Portal: `https://d-88672852fa.awsapps.com/start`

## Read-only user first login

The API cannot send the Identity Center invitation. After the first apply, open
IAM Identity Center (Asia Pacific (Malaysia)) → Users → `my-533d-readonly` and choose
**Send email verification link** or **Reset password**, then set the password and register MFA.
Use a private browser window so the admin session is not reused.
