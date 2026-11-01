# Read-only investigation access: one user, one group, one permission set,
# assigned to every active account in the organization.
# The user belongs only to this group, so ReadOnlyInvestigation is the only role it can use.

data "aws_ssoadmin_instances" "this" {}

data "aws_organizations_organization" "this" {}

locals {
  sso_instance_arn  = one(data.aws_ssoadmin_instances.this.arns)
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)

  # Picks up new accounts on the next apply.
  active_accounts = {
    for a in data.aws_organizations_organization.this.accounts : a.id => a.name
    if a.state == "ACTIVE"
  }
}

resource "aws_identitystore_user" "readonly" {
  identity_store_id = local.identity_store_id

  user_name    = "my-533d-readonly"
  display_name = "MY 533d ReadOnly"

  name {
    given_name  = "MY 533d"
    family_name = "ReadOnly"
  }

  emails {
    value   = "my-aws+readonly@533d.consulting"
    primary = true
  }
}

resource "aws_identitystore_group" "readonly_investigators" {
  identity_store_id = local.identity_store_id
  display_name      = "ReadOnlyInvestigators"
  description       = "Read-only access to every account for investigation."
}

resource "aws_identitystore_group_membership" "readonly" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.readonly_investigators.group_id
  member_id         = aws_identitystore_user.readonly.user_id
}

resource "aws_ssoadmin_permission_set" "readonly_investigation" {
  instance_arn     = local.sso_instance_arn
  name             = "ReadOnlyInvestigation"
  description      = "Read-only access for investigation (AWS managed ReadOnlyAccess)."
  session_duration = "PT1H"
}

# ReadOnlyAccess can read data as well as configuration (S3 objects, DynamoDB items, log contents).
resource "aws_ssoadmin_managed_policy_attachment" "readonly_investigation" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly_investigation.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_ssoadmin_account_assignment" "readonly_investigators" {
  for_each = local.active_accounts

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly_investigation.arn

  principal_type = "GROUP"
  principal_id   = aws_identitystore_group.readonly_investigators.group_id

  target_type = "AWS_ACCOUNT"
  target_id   = each.key

  # Attach the policy before provisioning the permission set into accounts.
  depends_on = [aws_ssoadmin_managed_policy_attachment.readonly_investigation]
}
