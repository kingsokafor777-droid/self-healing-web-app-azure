# Contributing

1. Create a branch and keep changes focused.
2. Run app tests: `cd app && python -m unittest -v`.
3. Run Terraform checks from `infra/`: `terraform fmt -recursive`, `terraform init -backend=false`, and `terraform validate`.
4. Never commit credentials, state, Terraform plan files, or real `terraform.tfvars` values.
5. Infrastructure applies require a reviewed plan and the manual production workflow. Do not run an apply against a shared subscription for testing.
6. For recovery changes, update the runbook and explain the signal, action, and residual limitations.
