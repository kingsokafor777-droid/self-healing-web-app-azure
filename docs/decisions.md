# Design Decisions

## App Service instead of Kubernetes

This project demonstrates application recovery with the smallest platform surface area that still provides worker health routing, automatic process recycling, managed TLS, and Azure Monitor integration. AKS would add cluster operations that do not help explain the selected self-healing mechanism.

## Health Check and Auto-Heal are separate controls

The `/health` endpoint is a readiness signal for routing. It reports unhealthy when the app is not ready. App Service Health Check removes unhealthy workers from the load balancer and can later return a recovered worker. Auto-Heal is a process-level recovery action that recycles the app after repeated HTTP 5xx responses. They address related but different failure modes.

## At least two workers

The default instance count is two, because traffic isolation is not meaningful with only one worker. The default Premium v3 SKU is a higher-cost, always-on demonstration footprint. Adjust it only after confirming the destination region supports the selected tier and that the resulting availability/cost trade-off is acceptable.

## OIDC and least privilege

GitHub Actions uses federated identity credentials and short-lived tokens rather than a client secret or publishing profile. The trust must be limited to this repository/environment and RBAC must be scoped to the application resource group and state container wherever possible.

## Separate state storage

Terraform's state is stored in a private Azure Storage container with blob lease locking. The state backend is separate from the application stack so it can survive `terraform destroy`. State may contain sensitive deployment metadata; access to the container must be restricted.

## Alerts do not remediate

The HTTP 5xx metric alert notifies operators. It does not trigger an automated restart. Automatically restarting on every alert can worsen an incident or hide evidence. The built-in Auto-Heal rule is bounded to a defined request threshold, while Health Check handles traffic removal.

## Explicit demo fault injection

Failure simulation is off by default and requires a Terraform opt-in. Keep it enabled only in an isolated demo environment. The fault injection makes the health check fail intentionally; it is not a production diagnostic feature.

## Not claimed as production-ready

This repository demonstrates infrastructure and operational patterns. A real service needs threat modeling, workload-specific readiness criteria, staged rollout, backup/restore for state, alert tuning, cost review, and a tested recovery objective. It has no multi-region failover or persistent data layer.
