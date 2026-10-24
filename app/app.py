"""A minimal Azure App Service workload for demonstrating health-based recovery."""

import logging
import os
from datetime import datetime, timezone

from flask import Flask, jsonify

if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    from azure.monitor.opentelemetry import configure_azure_monitor

    configure_azure_monitor()

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger("self_healing_demo")
app = Flask(__name__)


def failure_simulation_enabled():
    return os.getenv("ENABLE_FAILURE_SIMULATION", "false").lower() == "true"


def this_instance_is_targeted():
    target = os.getenv("SIMULATE_UNHEALTHY_INSTANCE_ID", "")
    current = os.getenv("WEBSITE_INSTANCE_ID", "")
    return failure_simulation_enabled() and bool(target) and current == target


@app.get("/")
def index():
    return jsonify(
        service="self-healing-web-app",
        status="ok",
        timestamp=datetime.now(timezone.utc).isoformat(),
        health_endpoint="/health",
        telemetry="Application Insights enabled" if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING") else "local mode",
    )


@app.get("/health")
def health():
    """App Service Health Check endpoint. Must return 2xx only when ready."""
    if this_instance_is_targeted():
        logger.error("Demo fault injection active on targeted instance %s", os.getenv("WEBSITE_INSTANCE_ID"))
        return jsonify(status="unhealthy", reason="demo fault injection"), 503
    return jsonify(status="healthy"), 200


@app.get("/live")
def live():
    """Process liveness endpoint, intentionally independent of readiness."""
    return jsonify(status="alive"), 200


@app.get("/demo/instance")
def demo_instance():
    """Expose the worker ID only during the explicitly enabled disposable demo."""
    if not failure_simulation_enabled():
        return jsonify(error="failure simulation is disabled"), 404
    return jsonify(instance_id=os.getenv("WEBSITE_INSTANCE_ID", "local")), 200


@app.get("/demo/fail")
def demo_fail():
    """Return a failure only on the selected worker in an opted-in test environment."""
    if not failure_simulation_enabled():
        return jsonify(error="failure simulation is disabled"), 404
    if this_instance_is_targeted():
        logger.warning("Demo fault injection endpoint hit targeted instance")
        return jsonify(status="simulated_failure"), 503
    return jsonify(status="healthy", message="This worker is not the selected fault-injection target."), 200


@app.get("/ready")
def ready():
    """Readiness endpoint suitable for a smoke test; mirrors the configured health path."""
    return health()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
