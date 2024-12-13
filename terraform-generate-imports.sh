#!/bin/bash

# Usage: terraform-imports-generate <state-list-file> <output-file>
# error out if the number of arguments is not 2
if [ $# -ne 2 ]; then
    echo "Usage: $0 <state-list-file> <output-file>"
    exit 1
fi

# File containing the list of Terraform state entries
LIST_FILE=$(realpath "$1")

# Prepare the output file by ensuring its directory exists
OUTPUT_DIR=$(dirname "$2")
mkdir -p "$OUTPUT_DIR" && touch "$2"
OUTPUT_FILE=$(realpath "$2")

# Use dirname to get the parent directory of the state file
workingDir=$(dirname "$LIST_FILE")

function found_terraform_resource_id() {
    entry=$1
    state=$2
    # Use terraform state show to get the details of the entry
    if [[ $entry == aws_iam_role_policy_attachment.* ]] || [[ $entry == *.aws_iam_role_policy_attachment.* ]]; then
        # Extract role and policy_arn for aws_iam_role_policy_attachment resources, removing quotes
        # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment#import
        role=$(terraform state show -state="$state" "$entry" | awk '/^ *role[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        policy_arn=$(terraform state show -state="$state" "$entry" | awk '/^ *policy_arn[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        attribute="$role/$policy_arn"
    elif [[ $entry == newrelic_nrql_alert_condition.* ]] || [[ $entry == *.newrelic_nrql_alert_condition.* ]]; then
        # Extract role and policy_arn for newrelic_nrql_alert_condition resources, removing quotes
        # See https://registry.terraform.io/providers/newrelic/newrelic/latest/docs/resources/nrql_alert_condition#import
        id=$(terraform state show -state="$state" "$entry" | awk '/^ *id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        type=$(terraform state show -state="$state" "$entry" | awk '/^ *type[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        attribute="$id:$type"
    elif [[ $entry == aws_service_discovery_private_dns_namespace.* ]] ||
        [[ $entry == *.aws_service_discovery_private_dns_namespace.* ]]; then
        # Extract the namespace ID and VPC ID
        namespace_id=$(terraform state show -state="$state" "$entry" | awk '/^ *id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        vpc=$(terraform state show -state="$state" "$entry" | awk '/^ *vpc[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')

        # Construct the combined attribute with the VPC ID appended
        attribute="${namespace_id}:${vpc}"
    elif [[ $entry == aws_elasticsearch_domain.* ]] || [[ $entry == *.aws_elasticsearch_domain.* ]]; then
        domain_name=$(terraform state show -state="$state" "$entry" | awk '/^ *domain_name[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        attribute="$domain_name"
    elif [[ $entry == aws_cloudwatch_metric_alarm.* ]] || [[ $entry == *.aws_cloudwatch_metric_alarm.* ]]; then
        alarm_name=$(terraform state show -state="$state" "$entry" |
            awk -F'=' '{
        # Strip leading and trailing spaces and quotes from the second field
        if (/^ *alarm_name[[:space:]]*=/) {
            gsub(/^ *"| *"$/, "", $2); # Remove leading and trailing spaces/quotes from value
            print $2;
            exit; # Exit after printing to avoid processing unnecessary lines
        }
    }')
        attribute="$alarm_name"
    elif [[ $entry == aws_lambda_permission.* ]] || [[ $entry == *.aws_lambda_permission.* ]]; then
        # Extract role and policy_arn for newrelic_nrql_alert_condition resources, removing quotes
        # See https://registry.terraform.io/providers/newrelic/newrelic/latest/docs/resources/nrql_alert_condition#import
        function_name=$(terraform state show -state="$state" "$entry" | awk '/^ *function_name[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        statement_id=$(terraform state show -state="$state" "$entry" | awk '/^ *statement_id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        attribute="$function_name/$statement_id"
    elif [[ $entry == newrelic_alert_policy.* ]] || [[ $entry == *.newrelic_alert_policy.* ]]; then
        # Extract role and policy_arn for newrelic_alert_policy resources, removing quotes
        # See https://registry.terraform.io/providers/newrelic/newrelic/latest/docs/resources/newrelic_alert_policy#import
        id=$(terraform state show -state="$state" "$entry" | awk '/^ *id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        account_id=$(terraform state show -state="$state" "$entry" | awk '/^ *account_id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        attribute="$id:$account_id"
    elif [[ $entry == mysql_grant.* ]] || [[ $entry == *.mysql_grant.* ]]; then
        # transform payments_adhoc_write@%:`payments`:* to payments_adhoc_write@%@payments@*
        attribute=$(terraform state show -state="$state" "$entry" | awk '/^ *id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}' | sed -e 's/:\`/@/g' -e 's/\`/@*/g' -e 's/:/@*@/g')
    elif [[ $entry == aws_security_group_rule.* ]] || [[ $entry == *.aws_security_group_rule.* ]]; then
        # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule#import
        read security_group_id type protocol from_port to_port cidr_blocks <<<$(terraform state show -state="$state" "$entry" | awk '
        /^ *security_group_id[[:space:]]*=[[:space:]]*/ {gsub(/"/, "", $3); sgi=$3}
        /^ *type[[:space:]]*=[[:space:]]*/ {gsub(/"/, "", $3); t=$3}
        /^ *protocol[[:space:]]*=[[:space:]]*/ {gsub(/"/, "", $3); p=$3}
        /^ *from_port[[:space:]]*=[[:space:]]*/ {gsub(/"/, "", $3); fp=$3}
        /^ *to_port[[:space:]]*=[[:space:]]*/ {gsub(/"/, "", $3); tp=$3}
        /^ *cidr_blocks[[:space:]]*=[[:space:]]*/ { inCidrBlock=1; next }
        inCidrBlock && /^\]/ { inCidrBlock=0 }
        inCidrBlock { gsub(/"/, "", $0); gsub(/,/, "", $0); cidr_blocks=cidr_blocks $0 " " }
        /^ *source_security_group_id[[:space:]]*=[[:space:]]*/ {gsub(/"/, "", $3); ssgi=$3}
        END {print sgi, t, p, fp, tp, cidr_blocks, ssgi}
    ')
        # Extract the first CIDR block from the list (assuming there might be more than one)
        cidr_block=$(echo $cidr_blocks | awk '{print $1}')
        # Construct the attribute string
        attribute="${security_group_id}_${type}_${protocol}_${from_port}_${to_port}_${cidr_block}${source_security_group_id}"
    elif [[ $entry == aws_appautoscaling_target.* ]] || [[ $entry == *.aws_appautoscaling_target.* ]]; then
        # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy#import
        service_namespace=$(terraform state show -state="$state" "$entry" | awk '/^ *service_namespace[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        resource_id=$(terraform state show -state="$state" "$entry" | awk '/^ *resource_id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        scalable_dimension=$(terraform state show -state="$state" "$entry" | awk '/^ *scalable_dimension[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        attribute="$service_namespace/$resource_id/$scalable_dimension"
    elif [[ $entry == aws_appautoscaling_policy.* ]] || [[ $entry == *.aws_appautoscaling_policy.* ]]; then
        # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy#import
        service_namespace=$(terraform state show -state="$state" "$entry" | awk '/^ *service_namespace[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        resource_id=$(terraform state show -state="$state" "$entry" | awk '/^ *resource_id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        scalable_dimension=$(terraform state show -state="$state" "$entry" | awk '/^ *scalable_dimension[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        name=$(terraform state show -state="$state" "$entry" | awk '/^ *name[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
        attribute="$service_namespace/$resource_id/$scalable_dimension/$name"
    else
        # Default to extracting id for all other resource types, removing quotes
        attribute=$(terraform state show -state="$state" "$entry" | awk '/^ *id[[:space:]]*=[[:space:]]*/ { gsub(/"/, "", $3); print $3; exit}')
    fi

    echo "$attribute"
}

# Ensure the output file is empty and add header
echo "# This file is automatically generated by https://github.com/amazingandyyy/terraform-utils" >"$OUTPUT_FILE"
echo "# It contains import statements for each resource in the source's state file $LIST_FILE" >>"$OUTPUT_FILE"
echo "# 1. Depends on the destination's terraform structure, you MIGHT need to modify the target for \`to\` for each block" >>"$OUTPUT_FILE"
echo "# 2. Some resource ids might NOT be correctly extracted, please verify the generated import statements" >>"$OUTPUT_FILE"
echo "# NOTE: Please verify the generated import statements before running them" >>"$OUTPUT_FILE"
echo "# NOTE: This script is extremely experimental and under active development, use it at your own risk." >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"

LIST=$(cat $LIST_FILE)
total_found=$(echo "$LIST" | wc -l | xargs) # Total items found in the state file

# Initialize counters
total_items=0

echo "Start processing $total_found items found in $LIST_FILE"

pushd "$workingDir" >/dev/null
# Read each line from the output of `terraform state list`
echo "$LIST" | while IFS= read -r entry; do
    let total_items+=1

    # Check for and skip certain entries
    if [[ $entry == data.* ]] || [[ $entry == *".data."* ]]; then
        echo "$total_items Skipping entry: $entry"
        echo "# $entry" >>"$OUTPUT_FILE"
        echo "# skip importing data resource" >>"$OUTPUT_FILE"
        echo "" >>"$OUTPUT_FILE"
        continue
    fi

    if [[ $entry == module.metadata.* ]]; then
        echo "$total_items Skipping entry: $entry"
        echo "# $entry" >>"$OUTPUT_FILE"
        echo "# skip importing metadata" >>"$OUTPUT_FILE"
        echo "" >>"$OUTPUT_FILE"
        continue
    fi

    if [[ $entry == *".random_password."* ]]; then
        echo "$total_items Skipping entry: $entry"
        echo "# $entry" >>"$OUTPUT_FILE"
        echo "# skip importing password, let it re-create because we are using aws_secretmanager and it will pick up new password" >>"$OUTPUT_FILE"
        echo "" >>"$OUTPUT_FILE"
        continue
    fi

    if [[ $entry == *".aws_iam_policy_attachment."* ]]; then
        echo "$total_items Skipping entry: $entry"
        echo "# $entry" >>"$OUTPUT_FILE"
        echo "# skip importing skip due to aws_iam_policy_attachment doesn’t support import" >>"$OUTPUT_FILE"
        echo "" >>"$OUTPUT_FILE"
        continue
    fi

    # Extract attribute and handle quotes
    attribute=$(found_terraform_resource_id "$entry" "$LIST_FILE")

    if [[ -z $attribute || $attribute == "null" ]]; then
        attribute="not found"
    fi

    echo "$total_items Resource attribute of $entry is $attribute"

    echo "import {" >>"$OUTPUT_FILE"
    echo "# previus: $entry" >>"$OUTPUT_FILE"
    echo "  to = $entry" >>"$OUTPUT_FILE"
    echo "  id = \"$attribute\"" >>"$OUTPUT_FILE"
    echo "}" >>"$OUTPUT_FILE"
    echo "" >>"$OUTPUT_FILE"
done
popd >/dev/null
