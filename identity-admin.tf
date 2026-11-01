# Named Identity Center admin for the access portal.
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

  user_name    = "my-533d-admin"
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
