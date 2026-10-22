import importlib.util
import unittest
from collections.abc import Mapping
from pathlib import Path


SCRIPT_PATH = Path(__file__).parents[1] / "scripts" / "sync-database-outputs.py"
SPEC = importlib.util.spec_from_file_location("sync_database_outputs", SCRIPT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Não foi possível carregar sync-database-outputs.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class RecordingHcpClient:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str, str, bool]] = []

    def set_workspace_variable(
        self,
        organization: str,
        workspace_name: str,
        key: str,
        value: str,
        *,
        sensitive: bool,
    ) -> None:
        self.calls.append((organization, workspace_name, key, value, sensitive))


class RecordingGitHubClient:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str, str]] = []

    def set_environment_variable(
        self, repository: str, environment: str, name: str, value: str
    ) -> None:
        self.calls.append((repository, environment, name, value))


class RecordingHcpApiClient(MODULE.HcpClient):
    def __init__(self, variables: list[Mapping[str, object]]) -> None:
        super().__init__("token")
        self.variables = variables
        self.requests: list[tuple[str, str, Mapping[str, object] | None]] = []

    def _request(
        self, method: str, path: str, payload: Mapping[str, object] | None = None
    ) -> Mapping[str, object]:
        self.requests.append((method, path, payload))
        if path.startswith("organizations/"):
            return {"data": {"id": "ws-123"}}
        if method == "GET" and "/vars" in path:
            return {"data": self.variables}
        return {}


class RecordingGitHubApiClient(MODULE.GitHubClient):
    def __init__(self, existing: bool) -> None:
        super().__init__("token")
        self.existing = existing
        self.requests: list[
            tuple[str, str, Mapping[str, object] | None, bool]
        ] = []

    def _request(
        self,
        method: str,
        path: str,
        payload: Mapping[str, object] | None = None,
        *,
        allow_not_found: bool = False,
    ) -> Mapping[str, object] | None:
        self.requests.append((method, path, payload, allow_not_found))
        if method == "GET":
            return {} if self.existing else None
        return {}


class SyncDatabaseOutputsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.outputs = {
            "jdbc_url": {
                "value": "jdbc:postgresql://database.example:5432/oficina"
            }
        }

    def test_syncs_auth_and_backend(self) -> None:
        hcp_client = RecordingHcpClient()
        github_client = RecordingGitHubClient()

        MODULE.sync_outputs(
            hcp_client,
            github_client,
            self.outputs,
            "oficina-org",
            "oficina-auth-homolog",
            "tiagomiele/oficina-os-service",
            "homolog",
        )

        self.assertEqual(
            hcp_client.calls,
            [
                (
                    "oficina-org",
                    "oficina-auth-homolog",
                    "db_url",
                    "jdbc:postgresql://database.example:5432/oficina?sslmode=require",
                    True,
                )
            ],
        )
        self.assertEqual(
            github_client.calls,
            [
                (
                    "tiagomiele/oficina-os-service",
                    "homolog",
                    "APP_DB_URL",
                    "jdbc:postgresql://database.example:5432/oficina",
                ),
                (
                    "tiagomiele/oficina-os-service",
                    "homolog",
                    "DEPLOY_ENABLED",
                    "true",
                ),
            ],
        )

    def test_rejects_missing_or_invalid_jdbc_url(self) -> None:
        with self.assertRaisesRegex(MODULE.SyncError, "jdbc_url"):
            MODULE.required_jdbc_url({})
        with self.assertRaisesRegex(MODULE.SyncError, "jdbc_url"):
            MODULE.required_jdbc_url({"jdbc_url": {"value": "postgres://invalid"}})

    def test_preserves_existing_query_parameters(self) -> None:
        value = "jdbc:postgresql://database.example/oficina?connectTimeout=10"
        self.assertEqual(
            MODULE.auth_jdbc_url(value),
            f"{value}&sslmode=require",
        )

    def test_hcp_upserts_sensitive_variable_and_removes_duplicates(self) -> None:
        client = RecordingHcpApiClient(
            [
                {
                    "id": "var-primary",
                    "attributes": {"key": "db_url", "category": "terraform"},
                },
                {
                    "id": "var-duplicate",
                    "attributes": {"key": "db_url", "category": "terraform"},
                },
            ]
        )

        client.set_workspace_variable(
            "oficina-org",
            "oficina-auth-homolog",
            "db_url",
            "jdbc:postgresql://database.example/oficina?sslmode=require",
            sensitive=True,
        )

        operations = [(method, path) for method, path, _ in client.requests]
        self.assertIn(("PATCH", "workspaces/ws-123/vars/var-primary"), operations)
        self.assertIn(("DELETE", "workspaces/ws-123/vars/var-duplicate"), operations)
        patch = next(
            payload
            for method, _, payload in client.requests
            if method == "PATCH"
        )
        self.assertTrue(patch["data"]["attributes"]["sensitive"])

    def test_github_creates_or_updates_environment_variable(self) -> None:
        create_client = RecordingGitHubApiClient(existing=False)
        create_client.set_environment_variable(
            "owner/backend", "homolog", "APP_DB_URL", "jdbc:value"
        )
        self.assertEqual(
            [request[0] for request in create_client.requests], ["GET", "POST"]
        )

        update_client = RecordingGitHubApiClient(existing=True)
        update_client.set_environment_variable(
            "owner/backend", "homolog", "APP_DB_URL", "jdbc:value"
        )
        self.assertEqual(
            [request[0] for request in update_client.requests], ["GET", "PATCH"]
        )


if __name__ == "__main__":
    unittest.main()
