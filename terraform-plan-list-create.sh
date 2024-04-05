#!/bin/bash

# Usage: terraform-imports-generate <state-file> <output-file>
# error out if the number of arguments is not 2
if [ $# -ne 1 ]; then
  echo "Usage: $0 <state-file> <output-file>"
  exit 1
fi

# File containing the list of Terraform state entries
SRC_FILE=$(realpath "$1")

# Prepare the output file by ensuring its directory exists
workingDir=$(dirname "$2")

pushd "$workingDir" > /dev/null
# terraform show | grep '^#' | sed 's/://g' | sed 's/#//g' | grep -v '^data.' | grep -v '.data' | grep -v '.metadata.' | sort > terraform-plan-list.txt
cat $SRC_FILE | grep '#' | grep "will be created$" | sed 's/://g' | sed 's/#//g' | grep -v '^data.' | grep -v '.data' | grep -v '.metadata.' | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*will be created$//' | sort > terraform-plan-created.txt
popd > /dev/null
