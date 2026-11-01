#!/usr/bin/env bash
# One-off enabling of the organization policy types Terraform attaches policies of.
# Terraform does not manage this without taking over the whole organization resource.
# Safe to re-run: types already enabled are skipped.
#
# Usage: AWS_PROFILE=my-adm-mgmt ./bootstrap/enable-policy-types.sh
set -euo pipefail

EXPECTED_ACCOUNT="277576839910"
POLICY_TYPES=("AISERVICES_OPT_OUT_POLICY")

account=$(aws sts get-caller-identity --query Account --output text)
if [[ "$account" != "$EXPECTED_ACCOUNT" ]]; then
  echo "Refusing to run: credentials are for account $account, expected $EXPECTED_ACCOUNT (Management)." >&2
  exit 1
fi

root_id=$(aws organizations list-roots --query 'Roots[0].Id' --output text)

for type in "${POLICY_TYPES[@]}"; do
  status=$(aws organizations list-roots --query "Roots[0].PolicyTypes[?Type=='$type'].Status | [0]" --output text)
  if [[ "$status" == "ENABLED" ]]; then
    echo "$type already enabled on $root_id."
  else
    aws organizations enable-policy-type --root-id "$root_id" --policy-type "$type" >/dev/null
    echo "Enabled $type on $root_id."
  fi
done
