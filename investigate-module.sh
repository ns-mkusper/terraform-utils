repo=${1:-terraform-null-systems-registry}
org=${2:-turo}

transform_q_string() {
    local input=$1

    # Extract the prefix and the main part of the module
    local prefix=$(echo "$input" | sed -E 's/terraform-([^-]+)-(.*)/\1/')
    local main_part=$(echo "$input" | sed -E 's/terraform-([^-]+)-(.*)/\2/')

    # Transform the main part to be first and the prefix to be last with a "/"
    echo "${main_part}/${prefix}"
}

usage=$(transform_q_string $repo)
github_search_url="https://github.com/search?q=org:$org+source+app.terraform.io%2F$org+$usage+language%3AHCL&type=code"

echo Repository: $repo
echo Organization: $org
echo ========================
echo Registry: https://app.terraform.io/app/$org/registry/modules/private/$org/$usage
echo Repo:     https://github.com/$org/$repo
echo Usage:    $github_search_url
echo ========================
