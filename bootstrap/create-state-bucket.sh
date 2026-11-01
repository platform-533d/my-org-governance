#!/usr/bin/env bash
# One-off creation of the Terraform state bucket for my-org-governance.
# Safe to re-run: every step is idempotent.
#
# Usage: AWS_PROFILE=my-adm-mgmt ./bootstrap/create-state-bucket.sh
set -euo pipefail

EXPECTED_ACCOUNT="277576839910"
REGION="ap-southeast-5"
BUCKET="my-org-governance-tfstate-${EXPECTED_ACCOUNT}"

account=$(aws sts get-caller-identity --query Account --output text)
if [[ "$account" != "$EXPECTED_ACCOUNT" ]]; then
  echo "Refusing to run: credentials are for account $account, expected $EXPECTED_ACCOUNT (Management)." >&2
  exit 1
fi

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket $BUCKET already exists - re-applying settings."
else
  echo "Creating bucket $BUCKET in $REGION"
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-ownership-controls --bucket "$BUCKET" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

# Versioning lets us recover any previous state.
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::${BUCKET}", "arn:aws:s3:::${BUCKET}/*"],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    }
  ]
}
EOF
)"

aws s3api put-bucket-tagging --bucket "$BUCKET" \
  --tagging 'TagSet=[{Key=ManagedBy,Value=bootstrap-script},{Key=Repo,Value=my-org-governance},{Key=Purpose,Value=terraform-state}]'

echo "Done. Verifying:"
aws s3api get-bucket-versioning --bucket "$BUCKET"
aws s3api get-public-access-block --bucket "$BUCKET"
