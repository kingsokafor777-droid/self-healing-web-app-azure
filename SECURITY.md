# Security

- Do not commit credentials, publish profiles, `.tfstate` files, `terraform.tfvars`, plan artifacts, or state backend credentials.
- Use three GitHub OIDC identities: a Terraform plan identity, a Terraform apply identity, and a narrowly scoped app-deployment identity. Do not create long-lived client secrets.
- Restrict the plan identity's federated subject to `repo:OWNER/REPOSITORY:environment:terraform-plan`. Restrict apply and deployment subjects to `repo:OWNER/REPOSITORY:environment:production`, and restrict production deployments to `main`.
- Create the application resource group before running Terraform. Scope plan access to Reader on that group and Storage Blob Data Contributor on the state container. Scope apply to Contributor on that group plus state-container access. Scope app deployment to Website Contributor on the individual web app. Do not grant subscription-wide Owner for routine automation.
- Keep FTP and WebDeploy publishing basic authentication disabled. Use Azure CLI 2.48.1 or newer so `az webapp deploy` uses Microsoft Entra authentication when SCM basic authentication is disabled.
- Protect the GitHub `production` environment with required reviewers. The Terraform apply job consumes the exact saved plan from private Azure Blob storage; it does not create a new plan after approval. Plan text and binary are never printed in public workflow logs. Grant reviewers read access through Entra RBAC and configure a lifecycle policy to expire the `plans/` prefix after one day. The workflow deletes plan blobs after an apply attempt when possible.
- Configure Azure Storage public blob access off, HTTPS-only, minimum TLS 1.2, and restricted network/RBAC access. Enable blob recovery/retention according to the state recovery policy.
- Keep the demo failure-injection variable disabled outside an isolated test environment. Never trigger faults against a real production workload.
- Report vulnerabilities privately to the repository owner. Do not include secrets or personal data in an issue.
