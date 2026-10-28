# Operations Runbook

## Expected behavior

| Signal | Mechanism | Automated response |
| --- | --- | --- |
| App readiness | App Service probes `/health` about once per minute | A worker failing repeated checks is removed from load balancing; healthy workers continue serving. |
| Repeated HTTP 5xx | App Service Auto-Heal status-code trigger | Recycles the app process after 10 matching requests in a five-minute interval, subject to a five-minute minimum process age. |
| HTTP 5xx metric | Azure Monitor `Http5xx` metric alert | Fires a severity-2 alert through the Action Group; email is optional. The alert does not itself restart the app. |
| Requests, traces, logs | Application Insights and Log Analytics workspace | Used to diagnose application-level failures and validate recovery. |

## Triage an alert

1. Open the app's Application Insights resource and inspect failures, exceptions, and request trends for the alert window.
2. Check App Service **Health check** instance status and current worker count. Confirm at least one healthy worker remains.
3. Check App Service logs and deployment history. Compare the first failing request with the most recent deployment or configuration change.
4. Verify `/health` returns 200 and `/live` returns 200. If all workers are unhealthy, use the Azure platform restart only after recording the incident evidence.
5. If a recent release caused the issue, roll back to the last known-good package and confirm the health endpoint recovers.
6. Close the alert only after the 5xx signal is back below threshold and the endpoint is stable.

## Safe fault-injection exercise

Only perform in a disposable test subscription or resource group. The exercise targets a single worker so healthy workers can remain in rotation.

1. Confirm `enable_failure_simulation = true` is restricted to the test environment, then apply and deploy.
2. Query `/demo/instance` repeatedly and record one worker ID. This diagnostics route is available only while the simulation feature is explicitly enabled.
3. Set Terraform input `failure_target_instance_id` to that exact worker ID and apply. Only requests handled by that worker should return 503 from `/health`; other workers should remain healthy. The target setting is managed by Terraform to avoid configuration drift.
4. Observe `/health`, instance health, routing behavior, Auto-Heal events, and the alert timeline. Health Check and Auto-Heal have thresholds and platform limits, so recovery is not instantaneous. If Azure replaces a worker and the ID changes, repeat the diagnostics lookup and retarget only in the test environment.
5. Clear `failure_target_instance_id`, set `enable_failure_simulation = false`, apply, and verify recovery. Terraform removes the target app setting; do not edit it out of band. Keep the feature disabled and redeploy the safe build before retaining the environment.

## Important limits

Health Check does not remove every unhealthy worker simultaneously by default. Worker replacements are constrained by Azure platform limits. A single worker cannot provide healthy-worker traffic failover. This sample has no cross-region failover, database recovery, queue replay, or business transaction validation. Use a canary or staging slot and add workload-specific probes before adapting this design to a real production service.
