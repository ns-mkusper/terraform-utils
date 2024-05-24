# terraform-utils

Better Terraform CLI experience with real use cases.

## Usage

First, pull the terraform state file from the remote.

```bash
terraform state pull > terraform.tfstate
```

Then use the `terraform.tfstate` as the `<state-file>` for the following use cases.

## Use cases

You can clone the repo and run scripts individually or use the following one-liners directly.

### generate terraform imports for all resources

## Usage

```bash
export TF_UTIL_VERSION=v1.8.0
curl -sSL "https://raw.githubusercontent.com/amazingandyyy/terraform-utils/$TF_UTIL_VERSION/terraform-imports-generate.sh" | bash -s -- <state-file> <output-file>
```

### terraform list with ids

```bash
export TF_UTIL_VERSION=v1.8.0
curl -sSL "https://raw.githubusercontent.com/amazingandyyy/terraform-utils/$TF_UTIL_VERSION/terraform-state-list-ids.sh" | bash -s -- <state-file>
```

### Investigate terraform module usage across the globe

```bash
export TF_UTIL_VERSION=v1.8.0
curl -sSL "https://raw.githubusercontent.com/amazingandyyy/terraform-utils/$TF_UTIL_VERSION/investigate-module.sh" | bash -s -- terraform-null-systems-registry turo
Repository: terraform-null-systems-registry
Organization: turo
========================
Registry:https://app.terraform.io/app/turo/registry/modules/private/turo/systems-registry/null
Repo:\t https://github.com/turo/terraform-null-systems-registry
Usage:\t https://github.com/search?q=org:turo+source+app.terraform.io%2Fturo+systems-registry/null+language%3AHCL&type=code
========================
```

## LICENSE

MIT

