# Security

- Do not commit credentials, publish profiles, `.tfstate` files, `terraform.tfvars`, plan artifacts, or state backend credentials.
- Use GitHub OIDC federation with a trust subject restricted to this repository's `production` environment. Prefer no long-lived client secrets.
- Scope Azure RBAC to the resource group and state container. The state writer should not receive subscription-wide Owner access for routine applies.
- Protect the production GitHub environment with required reviewers. Keep Terraform apply and app deployment manual.
- Review and retain Terraform plans as sensitive artifacts. They can contain values derived from infrastructure state.
- Keep the demo failure-injection variable disabled outside an isolated test environment. Never trigger faults against a real production workload.
- Configure Azure Storage public access off, HTTPS-only, minimum TLS 1.2, and restricted network/RBAC access. Enable blob recovery/retention according to the state recovery policy.
- Report vulnerabilities privately to the repository owner. Do not include secrets or personal data in an issue.
