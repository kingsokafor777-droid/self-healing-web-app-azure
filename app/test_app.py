import os
import unittest
from unittest.mock import patch

from app import app


class HealthEndpointTests(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()

    def test_home_returns_service_metadata(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["status"], "ok")

    def test_health_is_healthy_by_default(self):
        with patch.dict(os.environ, {"ENABLE_FAILURE_SIMULATION": "false"}, clear=True):
            response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["status"], "healthy")

    def test_health_only_fails_on_selected_instance(self):
        settings = {
            "ENABLE_FAILURE_SIMULATION": "true",
            "SIMULATE_UNHEALTHY_INSTANCE_ID": "worker-a",
            "WEBSITE_INSTANCE_ID": "worker-a",
        }
        with patch.dict(os.environ, settings, clear=True):
            response = self.client.get("/health")
        self.assertEqual(response.status_code, 503)

    def test_other_instances_remain_healthy(self):
        settings = {
            "ENABLE_FAILURE_SIMULATION": "true",
            "SIMULATE_UNHEALTHY_INSTANCE_ID": "worker-a",
            "WEBSITE_INSTANCE_ID": "worker-b",
        }
        with patch.dict(os.environ, settings, clear=True):
            response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)

    def test_liveness_stays_healthy_when_readiness_fails(self):
        settings = {
            "ENABLE_FAILURE_SIMULATION": "true",
            "SIMULATE_UNHEALTHY_INSTANCE_ID": "worker-a",
            "WEBSITE_INSTANCE_ID": "worker-a",
        }
        with patch.dict(os.environ, settings, clear=True):
            health_response = self.client.get("/health")
            live_response = self.client.get("/live")
            ready_response = self.client.get("/ready")
        self.assertEqual(health_response.status_code, 503)
        self.assertEqual(live_response.status_code, 200)
        self.assertEqual(ready_response.status_code, 503)

    def test_failure_diagnostics_are_hidden_by_default(self):
        with patch.dict(os.environ, {"ENABLE_FAILURE_SIMULATION": "false"}, clear=True):
            response = self.client.get("/demo/instance")
        self.assertEqual(response.status_code, 404)

    def test_instance_diagnostics_require_opt_in(self):
        settings = {"ENABLE_FAILURE_SIMULATION": "true", "WEBSITE_INSTANCE_ID": "worker-a"}
        with patch.dict(os.environ, settings, clear=True):
            response = self.client.get("/demo/instance")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["instance_id"], "worker-a")

    def test_failure_route_is_only_an_error_on_target_instance(self):
        settings = {
            "ENABLE_FAILURE_SIMULATION": "true",
            "SIMULATE_UNHEALTHY_INSTANCE_ID": "worker-a",
            "WEBSITE_INSTANCE_ID": "worker-b",
        }
        with patch.dict(os.environ, settings, clear=True):
            response = self.client.get("/demo/fail")
        self.assertEqual(response.status_code, 200)

    def test_failure_route_returns_503_on_target_instance(self):
        settings = {
            "ENABLE_FAILURE_SIMULATION": "true",
            "SIMULATE_UNHEALTHY_INSTANCE_ID": "worker-a",
            "WEBSITE_INSTANCE_ID": "worker-a",
        }
        with patch.dict(os.environ, settings, clear=True):
            response = self.client.get("/demo/fail")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json["status"], "simulated_failure")


if __name__ == "__main__":
    unittest.main()
