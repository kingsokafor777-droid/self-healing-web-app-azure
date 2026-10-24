#!/usr/bin/env bash
set -euo pipefail

# Creates a separate resource group and storage account for remote Terraform state.
# Run after `az login`; the signed-in identity must be allowed to create resources
# and have Storage Blob Data Contributor to create the container through Entra auth.

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <location> <state-resource-group> [subscription-id]" >&2
  exit 2
fi

location="$1"
resource_group="$2"
subscription_id="${3:-}"
if [[ -n "$subscription_id" ]]; then
  az account set --subscription "$subscription_id"
fi

suffix="$(python3 - <<'PY'
import secrets, string
print(''.join(secrets.choice(string.ascii_lowercase + string.digits) for _ in range(8)))
PY
)"
storage_account="tfstate${suffix}"
container="tfstate"

az group create --name "$resource_group" --location "$location" --output none
az storage account create \
  --name "$storage_account" \
  --resource-group "$resource_group" \
  --location "$location" \
  --sku Standard_GRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

az storage container create \
  --name "$container" \
  --account-name "$storage_account" \
  --auth-mode login \
  --public-access off \
  --output none

cat <<EOF
Remote state account created.
Set these GitHub variables (and use the same values for local terraform init):
TF_STATE_RESOURCE_GROUP=$resource_group
TF_STATE_STORAGE_ACCOUNT=$storage_account
TF_STATE_CONTAINER=$container
TF_STATE_KEY=self-healing-web-app.tfstate

The OIDC identity needs Storage Blob Data Contributor on the container and
sufficiently scoped Azure resource permissions for the Terraform deployment.
EOF
