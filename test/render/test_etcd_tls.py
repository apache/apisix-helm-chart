# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Render etcd TLS settings with Helm and PyYAML; no cluster is required."""

import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml


CHART = Path(__file__).resolve().parents[2] / "charts" / "apisix"


def external_etcd_values(client_auth=False, sni="etcd.example.test", verify=True):
    return {
        "apisix": {
            "ssl": {
                "enabled": True,
                "existingCASecret": "etcd-ca",
                "certCAFilename": "ca.crt",
            }
        },
        "etcd": {
            "enabled": False,
            "auth": {
                "tls": {
                    "enabled": client_auth,
                    "existingSecret": "etcd-client",
                    "certFilename": "client.crt",
                    "certKeyFilename": "client.key",
                    "verify": verify,
                    "sni": sni,
                }
            },
        },
        "externalEtcd": {"host": ["https://192.0.2.10:2379"], "user": ""},
    }


def render(values):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "values.yaml"
        path.write_text(yaml.safe_dump(values), encoding="utf-8")
        result = subprocess.run(
            ["helm", "template", "test-etcd", str(CHART), "-f", str(path)],
            check=True,
            capture_output=True,
            text=True,
        )
    resources = [resource for resource in yaml.safe_load_all(result.stdout) if resource]
    config_map = next(
        resource
        for resource in resources
        if resource.get("kind") == "ConfigMap"
        and "config.yaml" in resource.get("data", {})
    )
    workload = next(
        resource
        for resource in resources
        if resource.get("kind") in ("Deployment", "DaemonSet")
    )
    return (
        yaml.safe_load(config_map["data"]["config.yaml"]),
        workload["spec"]["template"]["spec"],
    )


class EtcdTLSRenderingTest(unittest.TestCase):
    def assert_client_mount(self, pod, enabled):
        container = next(item for item in pod["containers"] if item["name"] == "apisix")
        volumes = [item for item in pod["volumes"] if item["name"] == "etcd-ssl"]
        mounts = [
            item for item in container["volumeMounts"] if item["mountPath"] == "/etcd-ssl"
        ]
        if enabled:
            self.assertEqual(len(volumes), 1)
            self.assertEqual(volumes[0]["secret"]["secretName"], "etcd-client")
            self.assertEqual(len(mounts), 1)
            self.assertEqual(mounts[0]["name"], "etcd-ssl")
        else:
            self.assertEqual(volumes, [])
            self.assertEqual(mounts, [])

    def test_server_only_tls_keeps_sni_and_verify_without_client_credentials(self):
        for daemon_set in (False, True):
            for verify in (False, True):
                with self.subTest(daemon_set=daemon_set, verify=verify):
                    values = external_etcd_values(verify=verify)
                    values["useDaemonSet"] = daemon_set
                    config, pod = render(values)
                    self.assertEqual(
                        config["deployment"]["etcd"]["tls"],
                        {"verify": verify, "sni": "etcd.example.test"},
                    )
                    self.assertEqual(
                        config["apisix"]["ssl"]["ssl_trusted_certificate"],
                        "/usr/local/apisix/conf/ssl/ca.crt",
                    )
                    self.assertEqual(
                        config["deployment"]["etcd"]["host"],
                        ["https://192.0.2.10:2379"],
                    )
                    self.assert_client_mount(pod, False)

    def test_mtls_keeps_client_credentials_and_mounts(self):
        for daemon_set in (False, True):
            with self.subTest(daemon_set=daemon_set):
                values = external_etcd_values(client_auth=True)
                values["useDaemonSet"] = daemon_set
                config, pod = render(values)
                self.assertEqual(
                    config["deployment"]["etcd"]["tls"],
                    {
                        "cert": "/etcd-ssl/client.crt",
                        "key": "/etcd-ssl/client.key",
                        "verify": True,
                        "sni": "etcd.example.test",
                    },
                )
                self.assert_client_mount(pod, True)

    def test_empty_sni_is_omitted_with_or_without_client_credentials(self):
        for client_auth in (False, True):
            with self.subTest(client_auth=client_auth):
                config, pod = render(external_etcd_values(client_auth=client_auth, sni=""))
                self.assertNotIn("sni", config["deployment"]["etcd"]["tls"])
                self.assertTrue(config["deployment"]["etcd"]["tls"]["verify"])
                self.assert_client_mount(pod, client_auth)

    def test_external_http_scheme_is_preserved(self):
        values = external_etcd_values(sni="")
        values["externalEtcd"]["host"] = ["http://192.0.2.10:2379"]
        config, pod = render(values)
        self.assertEqual(config["deployment"]["etcd"]["host"], ["http://192.0.2.10:2379"])
        self.assert_client_mount(pod, False)

    def test_default_bundled_etcd_keeps_http_scheme(self):
        config, pod = render({})
        self.assertTrue(
            all(host.startswith("http://") for host in config["deployment"]["etcd"]["host"])
        )
        self.assert_client_mount(pod, False)


if __name__ == "__main__":
    unittest.main()
