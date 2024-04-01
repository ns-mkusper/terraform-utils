#!/bin/bash

# Usage: terraform-state-list-ids <state-file>
# Check for the correct number of arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 <state-file>"
  exit 1
fi

# File containing the list of Terraform state entries
STATE_FILE=$1

echo "Generate terraform state list with id based on $STATE_FILE..."
echo ""

# List entries from the Terraform state and process each
terraform state list -state="$STATE_FILE" | while IFS= read -r entry; do
  # Extract the ID of each entry
  id=$(terraform state show -state="$STATE_FILE" "$entry" | awk '/^ *id[[:space:]]*=[[:space:]]*"/ {print $3}')

  if [[ -z $id || $id == "null" ]]; then
    id="not found"
  fi

  # Print the entry and its ID
  echo "$entry $id"
done

