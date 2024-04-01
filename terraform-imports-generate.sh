#!/bin/bash

# Usage: terraform-generate-imports <state-file> <output-file>
# error out if the number of arguments is not 2
if [ $# -ne 2 ]; then
  echo "Usage: $0 <state-file> <output-file>"
  exit 1
fi

# File containing the list of Terraform state entries
STATE_FILE=$1

# Output file where the results will be saved
OUTPUT_FILE=$2

# Ensure the output file is empty
> "$OUTPUT_FILE"

LIST=$(terraform state list -state="$STATE_FILE")
total_found=$(echo "$LIST" | wc -l | xargs) # Total items found in the state file

# Initialize counters
total_items=0
skipped_items=0
id_found_items=0

echo "Start processing $total_found items found in the state file $STATE_FILE..."

# Reset skipped_items for accurate counting during the main loop
skipped_items=0

# Read each line from the output of `terraform state list`
echo "$LIST" | while IFS= read -r entry; do
  let total_items+=1
  
  # Check if the entry starts with module.metadata or contains .data.
  if [[ $entry == data.* ]] || [[ $entry == *".data."* ]]; then
    let skipped_items+=1
    echo "$total_items Skipping data block: $entry"
    echo "# $entry" >> "$OUTPUT_FILE"
    echo "# skip importing data blocks" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    continue
  fi
  
  # Skip entries that start with "module.metadata." and note the skip
  if [[ $entry == module.metadata.* ]]; then
    let skipped_items+=1
    echo "$total_items Skipping metadata module: $entry"
    echo "# $entry" >> "$OUTPUT_FILE"
    echo "# skip importing metadata modules" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    continue
  fi
  
  # Use terraform state show to get the details of the entry
  # and use awk to extract the ID
  id=$(terraform state show -state=$STATE_FILE $entry | awk '/^ *id[[:space:]]*=[[:space:]]*"/ {print $3}')
  if [[ -z $id || $id == "null" ]]; then
    id="\"not found\""
  else
    let id_found_items+=1
  fi
  
  echo "$total_items Resource id of $entry is $id"
  
  echo "# $entry" >> "$OUTPUT_FILE"
  echo "import {" >> "$OUTPUT_FILE"
  echo "  to = $entry" >> "$OUTPUT_FILE"
  echo "  id = $id" >> "$OUTPUT_FILE"
  echo "}" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
done

# Print summary information
echo "Summary:"
echo "Total items processed: $total_items"
echo "Skipped items: $skipped_items"
echo "Items with ID found: $id_found_items"
echo "Results saved to $OUTPUT_FILE"
