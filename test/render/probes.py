#!/usr/bin/env python3
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
"""Render regression checks; run with Python 3, PyYAML and Helm 3."""
import copy
import pathlib
import subprocess
import tempfile
import yaml

CHART = pathlib.Path(__file__).resolve().parents[2] / "charts/apisix"
class StrictLoader(yaml.SafeLoader):
    pass

def mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"Duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result
StrictLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)

def render(values=None, release="my-apisix", fail=False):
    values = copy.deepcopy(values or {})
    values.setdefault("etcd", {}).setdefault("auth", {}).setdefault("token", {})["enabled"] = False
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as f:
        yaml.safe_dump(values or {}, f); f.flush()
        proc = subprocess.run(["helm", "template", release, str(CHART), "-n", "gateway", "-f", f.name], capture_output=True, text=True)
    if fail:
        assert proc.returncode, "Expected invalid values to fail"
        return proc.stderr
    assert proc.returncode == 0, proc.stderr
    docs = [d for d in yaml.load_all(proc.stdout, Loader=StrictLoader) if d]
    ids = [(d["apiVersion"], d["kind"], d["metadata"].get("namespace", "gateway"), d["metadata"]["name"]) for d in docs]
    assert len(ids) == len(set(ids)), "Duplicate resource identities"
    for d in docs:
        if d["kind"] == "ConfigMap" and "config.yaml" in d.get("data", {}):
            yaml.load(d["data"]["config.yaml"], Loader=StrictLoader)
    return docs

def objects(docs, kind):
    return [d for d in docs if d["kind"] == kind]

def config(docs):
    return yaml.safe_load(next(d["data"]["config.yaml"] for d in docs if d["kind"] == "ConfigMap" and "config.yaml" in d.get("data", {})))

for provider in ("etcd", "yaml"):
    docs = render({"apisix": {"deployment": {"role_traditional": {"config_provider": provider}}, "status": {"port": 17085}}})
    c = objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["containers"][0]
    assert {"name": "status", "containerPort": 17085, "protocol": "TCP"} in c["ports"]
    assert c["readinessProbe"]["httpGet"]["path"] == "/status/ready"
    assert c["startupProbe"]["httpGet"]["path"] == "/status"
    assert config(docs)["apisix"]["status"]["port"] == 17085
for role in ("control_plane", "data_plane"):
    docs = render({"apisix": {"deployment": {"role": role}}})
    assert objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["containers"][0]["livenessProbe"]
docs = render({"apisix": {"status": {"enabled": False}}})
c = objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["containers"][0]
assert "startupProbe" not in c and "status" not in config(docs)["apisix"]
assert all(p["name"] != "status" for p in c["ports"])

for handler, action in (("tcpSocket", {"port": 9080}), ("exec", {"command": ["true"]}),
                        ("grpc", {"port": 9000})):
    docs = render({"apisix": {"status": {"probes": {"readinessProbe": {handler: action}}}}})
    probe = objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["containers"][0]["readinessProbe"]
    assert probe[handler] == action
    assert set(probe) & {"httpGet", "tcpSocket", "exec", "grpc"} == {handler}
assert "exactly one handler" in render({"apisix": {"status": {"probes": {
    "readinessProbe": {"httpGet": {"path": "/", "port": 9080}, "tcpSocket": {"port": 9080}}
}}}}, fail=True)
docs = render({"apisix": {"status": {"probes": {"livenessProbe": None,
    "readinessProbe": {"periodSeconds": 7}}}}})
c = objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["containers"][0]
assert not c.get("livenessProbe")
assert c["readinessProbe"]["periodSeconds"] == 7
assert c["readinessProbe"]["httpGet"]["path"] == "/status/ready"
docs = render({"apisix": {"status": {"probes": {"readinessProbe": {"httpGet": {"path": "/custom"}}}}}})
probe = objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["containers"][0]["readinessProbe"]
assert probe["httpGet"] == {"path": "/custom", "port": "status"}
print("probes: passed")
