# The single named admin for the Malaysian organization, signing in through
# the Identity Center access portal.
# AWSControlTowerAdmins is created and owned by Control Tower; it already holds
# AWSAdministratorAccess on the management, Audit and Log Archive accounts.
# Only the membership is managed here.

data "aws_identitystore_group" "control_tower_admins" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWSControlTowerAdmins"
    }
  }
}

resource "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id

  user_name    = "MY-533d-Admin"
  display_name = "MY 533d Admin"

  name {
    given_name  = "MY 533d"
    family_name = "Admin"
  }

  emails {
    value   = "my-aws+admin@533d.consulting"
    primary = true
  }
}

resource "aws_identitystore_group_membership" "admin_control_tower_admins" {
  identity_store_id = local.identity_store_id
  group_id          = data.aws_identitystore_group.control_tower_admins.group_id
  member_id         = aws_identitystore_user.admin.user_id
}

# Control Tower gives AWSControlTowerAdmins admin on the management, Audit and Log Archive
# accounts only; enrolled accounts get just AWSOrganizationsFullAccess. Admin on accounts
# in registered OUs is assigned here.
data "aws_ssoadmin_permission_set" "administrator_access" {
  instance_arn = local.sso_instance_arn
  name         = "AWSAdministratorAccess"
}

data "aws_organizations_organizational_unit_child_accounts" "registered" {
  for_each  = local.registered_ous
  parent_id = local.root_ou_ids[each.key]
}

locals {
  registered_ou_accounts = merge([
    for ou in data.aws_organizations_organizational_unit_child_accounts.registered :
    { for a in ou.accounts : a.id => a.name if a.status == "ACTIVE" }
  ]...)
}

resource "aws_ssoadmin_account_assignment" "control_tower_admins" {
  for_each = local.registered_ou_accounts

  instance_arn       = local.sso_instance_arn
  permission_set_arn = data.aws_ssoadmin_permission_set.administrator_access.arn

  principal_type = "GROUP"
  principal_id   = data.aws_identitystore_group.control_tower_admins.group_id

  target_type = "AWS_ACCOUNT"
  target_id   = each.key
}
