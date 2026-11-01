# Registers OUs with Control Tower by enabling AWSControlTowerBaseline on them.
# A registered OU gets the mandatory controls, including the region deny that keeps
# workloads in ap-southeast-5, and its accounts are enrolled automatically.
# Account Factory is not available in ap-southeast-5, so moving an account into a
# registered OU is how accounts are enrolled here.
# The Security OU (Audit, Log Archive) is governed by the landing zone itself.

locals {
  # AWSControlTowerBaseline 5.0 is the version for landing zone 4.0.
  control_tower_baseline_arn     = "arn:aws:controltower:ap-southeast-5::baseline/17BSJV3IGJ2QSGA2"
  control_tower_baseline_version = "5.0"

  # IdentityCenterBaseline enabled on the management account by the landing zone;
  # required as a parameter while Identity Center access management is on.
  identity_center_enabled_baseline_arn = "arn:aws:controltower:ap-southeast-5:277576839910:enabledbaseline/XAGWVZGDSNI606E28"

  registered_ous = toset(["Sandbox"])
}

data "aws_organizations_organizational_units" "root" {
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

locals {
  root_ou_arns = { for ou in data.aws_organizations_organizational_units.root.children : ou.name => ou.arn }
}

resource "aws_controltower_baseline" "ou" {
  for_each = local.registered_ous

  baseline_identifier = local.control_tower_baseline_arn
  baseline_version    = local.control_tower_baseline_version
  target_identifier   = local.root_ou_arns[each.key]

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = local.identity_center_enabled_baseline_arn
  }
}
