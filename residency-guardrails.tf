# Residency guardrails on top of Control Tower's mandatory controls.
# Region deny only checks where an API call is made; these close the paths where a
# call made in ap-southeast-5 still sends data elsewhere, plus credential and
# organization escape hatches. Attached to Sandbox first; extend guarded_ous to
# Workloads once tested.
# SCPs never apply to the management account, so workloads never run there.

locals {
  guarded_ous = toset(["Sandbox"])

  root_ou_ids = { for ou in data.aws_organizations_organizational_units.root.children : ou.name => ou.id }

  # Control Tower elective controls, by Control Catalog ARN.
  residency_controls = {
    "AWS-GR_RESTRICT_ROOT_USER"                   = "arn:aws:controlcatalog:::control/5kvme4m5d2b4d7if2fs5yg2ui"
    "AWS-GR_RESTRICT_ROOT_USER_ACCESS_KEYS"       = "arn:aws:controlcatalog:::control/8ui9y3oace2513xarz8aqojl7"
    "AWS-GR_RESTRICT_S3_CROSS_REGION_REPLICATION" = "arn:aws:controlcatalog:::control/3zbcht7oxkzts9r1z20nz5lcw"
  }

  guarded_ou_controls = {
    for pair in setproduct(local.guarded_ous, keys(local.residency_controls)) :
    "${pair[0]}/${pair[1]}" => { ou = pair[0], control = pair[1] }
  }
}

resource "aws_controltower_control" "residency" {
  for_each = local.guarded_ou_controls

  control_identifier = local.residency_controls[each.value.control]
  target_identifier  = local.root_ou_arns[each.value.ou]

  # Control Tower registers the OU first.
  depends_on = [aws_controltower_baseline.ou]
}

data "aws_iam_policy_document" "residency_guardrails" {
  statement {
    sid       = "DenyDynamoDBReplicas"
    effect    = "Deny"
    actions   = ["dynamodb:CreateTableReplica"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyECRReplication"
    effect    = "Deny"
    actions   = ["ecr:PutReplicationConfiguration"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyBackupCopyOutsideMalaysia"
    effect    = "Deny"
    actions   = ["backup:CopyFromBackupVault"]
    resources = ["*"]

    condition {
      test     = "ForAnyValue:ArnNotLike"
      variable = "backup:CopyTargets"
      values   = ["arn:aws:backup:ap-southeast-5:*:backup-vault:*"]
    }
  }

  statement {
    sid       = "DenyBackupCopyOutsideOrganization"
    effect    = "Deny"
    actions   = ["backup:CopyFromBackupVault"]
    resources = ["*"]

    condition {
      test     = "ForAnyValue:StringNotLike"
      variable = "backup:CopyTargetOrgPaths"
      values   = ["${data.aws_organizations_organization.this.id}/*"]
    }
  }

  # These APIs cannot tell an in-organization share from an external one, so all are denied.
  statement {
    sid    = "DenySnapshotAndImageSharing"
    effect = "Deny"
    actions = [
      "ec2:ModifySnapshotAttribute",
      "ec2:ModifyImageAttribute",
      "rds:ModifyDBSnapshotAttribute",
      "rds:ModifyDBClusterSnapshotAttribute",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyExternalResourceShares"
    effect    = "Deny"
    actions   = ["ram:CreateResourceShare", "ram:UpdateResourceShare"]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "ram:RequestedAllowsExternalPrincipals"
      values   = ["true"]
    }
  }

  statement {
    sid       = "DenyLeavingOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }

  # Humans sign in through Identity Center; workloads use roles.
  statement {
    sid       = "DenyIAMUserCredentials"
    effect    = "Deny"
    actions   = ["iam:CreateUser", "iam:CreateAccessKey", "iam:CreateLoginProfile"]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "residency_guardrails" {
  name        = "my-residency-guardrails"
  description = "Blocks copying data out of ap-southeast-5 or the organization, leaving the organization, and IAM user credentials."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.residency_guardrails.json
}

resource "aws_organizations_policy_attachment" "residency_guardrails" {
  for_each = local.guarded_ous

  policy_id = aws_organizations_policy.residency_guardrails.id
  target_id = local.root_ou_ids[each.key]
}

# Opts every account out of AWS using content from AI services (Comprehend,
# Transcribe, Rekognition and others) to improve those services.
# Requires the AISERVICES_OPT_OUT_POLICY policy type: bootstrap/enable-policy-types.sh.
resource "aws_organizations_policy" "ai_opt_out" {
  name        = "my-ai-services-opt-out"
  description = "Opts all accounts out of AI services content use."
  type        = "AISERVICES_OPT_OUT_POLICY"

  content = jsonencode({
    services = {
      default = {
        opt_out_policy = { "@@assign" = "optOut" }
      }
    }
  })
}

resource "aws_organizations_policy_attachment" "ai_opt_out_root" {
  policy_id = aws_organizations_policy.ai_opt_out.id
  target_id = data.aws_organizations_organization.this.roots[0].id
}
