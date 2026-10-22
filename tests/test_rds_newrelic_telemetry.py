import importlib.util
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


MODULE_PATH = Path(__file__).parents[1] / "lambda" / "rds_newrelic_telemetry.py"


def load_module():
    boto3 = MagicMock()
    with patch.dict(sys.modules, {"boto3": boto3}):
        spec = importlib.util.spec_from_file_location("rds_newrelic_telemetry", MODULE_PATH)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    return module


class RdsNewRelicTelemetryTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def test_selects_regional_event_endpoint(self):
        with patch.dict(os.environ, {"NEW_RELIC_ACCOUNT_ID": "123"}, clear=False):
            self.assertEqual(
                self.module._events_endpoint("123", "US"),
                "https://insights-collector.newrelic.com/v1/accounts/123/events",
            )
            self.assertEqual(
                self.module._events_endpoint("123", "EU"),
                "https://insights-collector.eu01.nr-data.net/v1/accounts/123/events",
            )

    def test_handler_publishes_only_aggregated_attributes(self):
        environment = {
            "ENVIRONMENT": "homolog",
            "RDS_INSTANCE_IDENTIFIER": "oficina-homolog-db",
            "RDS_LOG_GROUP_NAME": "/aws/rds/instance/oficina-homolog-db/postgresql",
        }
        with (
            patch.dict(os.environ, environment, clear=False),
            patch.object(self.module, "_count_logs", side_effect=[2, 1]),
            patch.object(self.module, "_latest_metric", return_value=12.5),
            patch.object(self.module, "_send_event") as send_event,
        ):
            result = self.module.handler({}, None)

        sample = send_event.call_args.args[0]
        self.assertEqual(result, {"status": "sent"})
        self.assertEqual(sample["eventType"], "OficinaRdsSample")
        self.assertEqual(sample["environment"], "homolog")
        self.assertEqual(sample["databaseIdentifier"], "oficina-homolog-db")
        self.assertEqual(sample["postgresErrorCount"], 2)
        self.assertEqual(sample["slowQueryCount"], 1)
        self.assertNotIn("message", sample)
        self.assertNotIn("sql", sample)
        self.assertNotIn("credentials", sample)


if __name__ == "__main__":
    unittest.main()
