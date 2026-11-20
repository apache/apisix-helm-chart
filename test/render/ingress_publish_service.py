#!/usr/bin/env python3
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
import pathlib
import subprocess
import tempfile
import yaml

chart = pathlib.Path(__file__).resolve().parents[2] / "charts/apisix"
for release, overrides in [
    ("apisix", {}), ("prod", {}), ("prod", {"fullnameOverride": "edge"}),
    ("prod", {"nameOverride": "edge"}),
    ("prod", {"service": {"gateway": {"name": "not-a-supported-override-on-this-chart"}}}),
    ("prod", {"ingress-controller": {"gatewayProxy": {"publishService": "other/external"}}}),
    ("prod", {"ingress-controller": {"gatewayProxy": {"statusAddress": ["192.0.2.1"]}}}),
]:
    overrides.setdefault("ingress-controller", {})["enabled"] = True
    overrides["etcd"] = {"auth": {"token": {"enabled": False}}}
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as f:
        yaml.safe_dump(overrides, f); f.flush()
        result = subprocess.run(["helm", "template", release, str(chart), "-n", "gateway", "-f", f.name],
                                capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    docs = [doc for doc in yaml.safe_load_all(result.stdout) if doc]
    proxy = next(doc for doc in docs if doc["kind"] == "GatewayProxy")
    service = next(doc for doc in docs if doc["kind"] == "Service" and
                   doc["metadata"].get("labels", {}).get("app.kubernetes.io/service") == "apisix-gateway")
    settings = overrides["ingress-controller"].get("gatewayProxy", {})
    if settings.get("statusAddress"):
        assert "publishService" not in proxy["spec"]
    else:
        assert proxy["spec"]["publishService"] == settings.get("publishService", "gateway/" + service["metadata"]["name"])
print("ingress_publish_service: passed")
