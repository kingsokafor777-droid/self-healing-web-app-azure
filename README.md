# Self-Healing Web App on Azure

A reproducible infrastructure portfolio project that deploys a small Python web app to Azure App Service and demonstrates health-based traffic isolation, process recovery, telemetry, alerting, and credential-free GitHub Actions. Azure resources are defined in Terraform. CI uses no Azure credentials.

> **Cost and safety:** The default plan uses Premium v3 with two workers so health-based traffic removal can leave a healthy instance serving requests. This is a resilient demonstration footprint, not a free-tier deployment. Review the Terraform plan and Azure pricing for your region before applying. Infrastructure apply and app deployment are manual, restricted to `main`, and use GitHub OIDC. No Azure deployment has been run as part of preparing this repository.

## Architecture

![Azure self-healing web app architecture](docs/architecture.png)

Editable diagram source: [`docs/architecture.mmd`](docs/architecture.mmd).

The health check and auto-heal are complementary. The health endpoint informs App Service routing so traffic can be removed from an unhealthy worker. The auto-heal rule recycles the app process after repeated HTTP 5xx responses. Azure Monitor alerts operations; the alert itself is **not** an automatic restart action. Application Insights and Log Analytics provide telemetry for diagnosis.

With two or more workers, health-based removal can preserve service while a bad worker recovers. Health Check may replace a worker only within Azure's platform limits. It does not guarantee zero downtime, and the sample has no database, queue, or cross-region failover.

## Repository map

- `infra/` — AzureRM Terraform configuration, inputs, outputs, and safe example values.
- `app/` — Flask sample app with `/health`, `/live`, `/ready`, and opt-in, instance-targeted failure simulation.
- `.github/workflows/ci.yml` — Python unit tests, dependency vulnerability audit, and Terraform static validation.
- `.github/workflows/terraform.yml` — manual OIDC plan and apply jobs that reuse the exact saved plan.
- `.github/workflows/deploy-app.yml` — manual, tested ZIP deployment with Azure Oryx build automation.
- `docs/` — architecture diagram, runbook, and design decisions.

## Prerequisites

- An Azure subscription, a pre-existing application resource group, and permissions to create the listed resources within it.
- Terraform 1.17.0 (the CI-tested version), Python 3.12, Azure CLI, and Git for local work.
- A globally unique Web App name and a separate private Storage account/container for Terraform state.
- GitHub Actions enabled, a `terraform-plan` environment restricted to `main` without required reviewers, and a protected `production` environment with required reviewers and a `main`-only deployment branch rule.
- Three Microsoft Entra app registrations/service principals with federated identity credentials. Do not create client secrets or use an App Service publishing profile.

## OIDC identities and GitHub variables

Use separate workload identities so each workflow has only the access it needs. Configure the plan identity's federated credential with subject `repo:OWNER/REPOSITORY:environment:terraform-plan`. Configure the apply and app-deploy identities with subject `repo:OWNER/REPOSITORY:environment:production`; the audience is `api://AzureADTokenExchange`.

Create the application resource group outside Terraform so the workflow identities can be scoped to that already-existing group; all Terraform-managed resources stay inside it. Grant the plan identity **Reader** on the application resource group and **Storage Blob Data Contributor** only on the Terraform state container. Grant the apply identity **Contributor** on the application resource group and **Storage Blob Data Contributor** on the state container. Grant the deployment identity **Website Contributor** scoped to the specific web app. Do not give routine workflows subscription-wide Owner access. Review your Azure role assignment and organizational policies before running.

Before the first deployment, have a subscription administrator register the resource providers used by the project (`Microsoft.Web`, `Microsoft.Insights`, `Microsoft.OperationalInsights`, and `Microsoft.Storage`). The Terraform workflows skip provider registration so their identities do not need subscription-wide registration rights. Terraform disables FTP and WebDeploy publishing basic authentication; Azure CLI 2.48.1 or later uses Microsoft Entra authentication for `az webapp deploy` when SCM basic authentication is disabled.

```bash
for namespace in Microsoft.Web Microsoft.Insights Microsoft.OperationalInsights Microsoft.Storage; do
  az provider register --namespace "$namespace"
done
```

Set the following as repository-level GitHub **variables** so both plan and apply jobs can read the non-secret identifiers:

| Variable | Purpose |
| --- | --- |
| `AZURE_PLAN_CLIENT_ID` | Client ID for the read-oriented Terraform plan identity. |
| `AZURE_APPLY_CLIENT_ID` | Client ID for the protected Terraform apply identity. |
| `AZURE_DEPLOY_CLIENT_ID` | Client ID for the app-only deployment identity. |
| `AZURE_TENANT_ID` | Entra tenant ID shared by the identities. |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription targeted by Terraform and deployment. |
| `TF_STATE_RESOURCE_GROUP` | Resource group containing the state Storage account. |
| `TF_STATE_STORAGE_ACCOUNT` | Existing Storage account name for remote state. |
| `TF_STATE_CONTAINER` | Private blob container for Terraform state. |
| `TF_STATE_KEY` | State blob name, for example `self-healing-web-app.tfstate`. |
| `APP_RESOURCE_GROUP` | Existing application resource group used by Terraform and app deployment. |
| `APP_SERVICE_NAME` | Globally unique App Service name created by Terraform. |

Protect `production` with a required reviewer and restrict deployments to `main`. Plan text and the optional apply binary are stored only in the private Azure state container under the `plans/` prefix; workflow logs reveal the blob path, not the plan contents. Give human approvers read access through Entra RBAC, and configure a Blob lifecycle rule to delete objects under `plans/` after one day. A successful or failed apply deletes its two plan blobs. If an approval is rejected or the run is canceled before apply starts, the lifecycle rule expires the leftover files. Terraform applies the exact reviewed plan and rejects it if remote state has changed.

## Run locally

1. Sign in with Azure CLI using `az login` and select the subscription with `az account set --subscription <subscription-id>`. Create the application resource group with `az group create --name <app-resource-group> --location <region>`. Create a separate state account with `scripts/bootstrap-state.sh <location> <state-resource-group> [subscription-id]`, or use an existing private account and container.
2. Copy `infra/terraform.tfvars.example` to `infra/terraform.tfvars`. Set `subscription_id`, `app_resource_group_name`, and a globally unique `web_app_name`; keep failure simulation disabled.
3. From `infra/`, initialize the partial Azure Storage backend. For local Azure CLI authentication, use `use_azuread_auth=true`; the GitHub workflow configures OIDC explicitly:

   ```bash
   cd infra
   terraform init \
     -backend-config="resource_group_name=$TF_STATE_RESOURCE_GROUP" \
     -backend-config="storage_account_name=$TF_STATE_STORAGE_ACCOUNT" \
     -backend-config="container_name=$TF_STATE_CONTAINER" \
     -backend-config="key=self-healing-web-app.tfstate" \
     -backend-config="use_azuread_auth=true"
   ```

   Do not commit backend configuration if your policy treats the values as sensitive.
4. Run `terraform fmt -recursive`, `terraform validate`, and `terraform plan`. Review the plan, region, SKU, worker count, resource count, and estimated costs. Apply only when ready to create billable resources.
5. Deploy the app using `.github/workflows/deploy-app.yml` after configuring GitHub variables and OIDC trust. The workflow tests and audits the app, then sends a source ZIP containing `app.py` and `requirements.txt`; Azure Oryx installs the dependencies during deployment. Verify the URL, `/health`, and `/live` responses.

The Azure Storage backend uses Azure Blob leases for state locking. Keep state remote and encrypted. The state container also holds private, short-lived plan files under `plans/`; set a lifecycle rule for that prefix without affecting the state blob. Never commit `terraform.tfstate`, `terraform.tfstate.backup`, `.terraform/`, `terraform.tfvars`, or plan files.

## GitHub Actions flow

Pull requests and pushes to `main` run the Python tests, `pip-audit`, and Terraform formatting/validation without Azure access. You can also dispatch CI manually.

Run `Terraform` from the Actions tab on `main`. The plan job runs in the `terraform-plan` environment with the plan-only identity and writes its readable plan to a private Azure blob. It prints only the blob path in the public workflow log. Download and inspect that text file from a trusted machine before proceeding:

```bash
az storage blob download \
  --account-name "$TF_STATE_STORAGE_ACCOUNT" \
  --container-name "$TF_STATE_CONTAINER" \
  --name "plans/<run-id>.txt" \
  --file plan.txt \
  --auth-mode login \
  --output none
```

Leave `confirm_apply` false for plan-only use. If you set it true, the workflow also stores the exact binary plan in the private container and starts a separate apply job in the protected `production` environment. Only approve that job after inspecting the private plan; the apply job downloads and uses that same plan and does not generate a replacement after review.

Run `Deploy app` manually from `main` after the infrastructure exists. The protected job validates required variables, reruns tests and the vulnerability audit, builds a root-correct ZIP package, authenticates with the deploy-only OIDC identity, and deploys through Azure CLI. It does not use publishing credentials.

## Failure demonstration

The production-safe default keeps `ENABLE_FAILURE_SIMULATION=false` and the target instance ID unset. In a disposable test environment only, set `enable_failure_simulation = true` in Terraform variables, apply, and deploy. Query `/demo/instance` repeatedly to see worker IDs, then set Terraform input `failure_target_instance_id` to exactly one worker ID and apply. Only that worker returns 503 from `/health`; other workers remain healthy and can continue serving traffic while Health Check removes the bad worker from routing. Observe the Auto-Heal threshold and Azure Monitor alert. Clear `failure_target_instance_id`, set `enable_failure_simulation = false`, apply, and verify recovery. App-setting changes can restart the app; if worker IDs change, query them again before targeting.

Do not expose diagnostic or failure routes in production. Both are disabled (404) by default and remain instructional fault-injection controls, not an attack simulator. Health-check and configuration changes can restart the app.

## Clean up

After preserving any evidence needed for your portfolio, run `terraform destroy` from `infra/` with the same backend and variables. Review the destroy plan first. The application resource group and state Storage account are both outside Terraform and are not destroyed by this project. Retain or delete them deliberately according to your recovery and state-retention policy.

## Validation status

The local audit runs the application tests, checks Python syntax, audits the pinned dependencies, runs Gunicorn health-route smoke tests, verifies the deployment ZIP layout, and validates Terraform formatting/configuration without Azure access. The GitHub Actions workflow provides the same repeatable checks. Azure authentication, live provisioning, alert delivery, and recovery behavior still require a configured Azure subscription and have not been represented as tested here.

## References

- [Azure App Service Health Check](https://learn.microsoft.com/en-us/azure/app-service/monitor-instances-health-check)
- [Deploy files to Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/deploy-zip)
- [Configure a Linux Python app for Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/configure-language-python)
- [Terraform Azure Linux Web App](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app)
- [Terraform Azure Monitor metric alert](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_metric_alert)
- [Terraform AzureRM backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [GitHub deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [Azure Login GitHub Action with OpenID Connect](https://github.com/Azure/login#login-with-openid-connect-oidc-recommended)
