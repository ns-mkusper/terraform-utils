#!/bin/bash

# Usage: terraform-state-list-ids <state-file>
# Check for the correct number of arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 <state-file>"
  exit 1
fi

# File containing the list of Terraform state entries
STATE_FILE=$1

function found_terraform_resource_id() {
  entry=$1
  STATE_FILE=$2
  # Use terraform state show to get the details of the entry
  if [[ $entry == *.aws_iam_role_policy_attachment.* ]]; then
    # Based on https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment#import
    # handle aws_iam_role_policy_attachment resources differently
    # Extract role for aws_iam_role_policy_attachment resources
    role=$(terraform state show -state=$STATE_FILE $entry | awk '/^ *role[[:space:]]*=[[:space:]]*"/ {print $3; exit}')
    # Extract policy_arn for aws_iam_role_policy_attachment resources
    policy_arn=$(terraform state show -state=$STATE_FILE $entry | awk '/^ *policy_arn[[:space:]]*=[[:space:]]*"/ {print $3; exit}')
    attribute="$role/$policy_arn"
  else
    # Default to extracting id for all other resource types
    attribute=$(terraform state show -state=$STATE_FILE $entry | awk '/^ *id[[:space:]]*=[[:space:]]*"/ {print $3; exit}')
  fi
}


echo "Generate terraform state list with id based on $STATE_FILE..."
echo ""

# List entries from the Terraform state and process each
terraform state list -state="$STATE_FILE" | while IFS= read -r entry; do
  # Extract the ID of each entry
  id=$(found_terraform_resource_id $entry $STATE_FILE)

  if [[ -z $id || $id == "null" ]]; then
    id="not found"
  fi

  # Print the entry and its ID
  echo "$entry $id"
done
