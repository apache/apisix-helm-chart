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
import pathlib
import copy
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
    return yaml.safe_load(next(d["data"]["config.yaml"] for d in docs if d["kind"] == "ConfigMap" and "config.yaml" in d.get("data", {}) and "apisix" in yaml.safe_load(d["data"]["config.yaml"])))

raw = "apisix:\n  node_listen: 19080\ndeployment:\n  role: data_plane\n  role_data_plane:\n    config_provider: yaml\n# literal {{ value }} remains literal\n"
docs = render({"apisix": {"fullCustomConfig": {"enabled": True, "configString": raw}}})
cm = next(d for d in objects(docs, "ConfigMap") if "config.yaml" in d.get("data", {}))
assert "{{ value }}" in cm["data"]["config.yaml"]
assert yaml.safe_load(cm["data"]["config.yaml"])["deployment"]["role"] == "data_plane"
docs = render({"apisix": {"fullCustomConfig": {"enabled": True, "existingConfigMap": "external", "revision": "v2"}}})
assert not any("config.yaml" in d.get("data", {}) for d in objects(docs, "ConfigMap"))
pod = objects(docs, "Deployment")[0]["spec"]["template"]
assert pod["metadata"]["annotations"]["checksum/config"] == "v2"
assert next(v for v in pod["spec"]["volumes"] if v["name"] == "apisix-config")["configMap"]["name"] == "external"
assert "choose exactly one" in render({"apisix": {"fullCustomConfig": {"enabled": True, "configString": raw, "config": {"apisix": {}}}}}, fail=True)
for key in ("edd1c9f034335f136f87ad84b625c8f1", "4054f7cf07e344346cd3f287985e76a2"):
    unsafe = {"deployment": {"role": "traditional", "admin": {
        "admin_key": [{"name": "admin", "role": "admin", "key": key}]}}}
    for source, value in (("config", unsafe), ("configString", yaml.safe_dump(unsafe))):
        error = render({"apisix": {"fullCustomConfig": {"enabled": True, source: value}}}, fail=True)
        assert "ADMIN KEY ERROR" in error and f"fullCustomConfig.{source}" in error

print("runtime_config: passed")
