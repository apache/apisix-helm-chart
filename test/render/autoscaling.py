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

values = {"autoscaling": {"enabled": True}, "resources": {"requests": {"cpu": "100m", "memory": "128Mi"}}}
docs = render(values)
h = objects(docs, "HorizontalPodAutoscaler")[0]
d = objects(docs, "Deployment")[0]
assert h["spec"]["scaleTargetRef"]["name"] == d["metadata"]["name"]
assert "replicas" not in d["spec"]
assert len(h["spec"]["metrics"]) == 2
assert "resources.requests" in render({"autoscaling": {"enabled": True}}, fail=True)
metric = {"type": "Pods", "pods": {"metric": {"name": "requests_per_second"}, "target": {"type": "AverageValue", "averageValue": "100"}}}
behavior = {"scaleDown": {"stabilizationWindowSeconds": 300}}
docs = render({"autoscaling": {"enabled": True, "metrics": [metric], "behavior": behavior}})
h = objects(docs, "HorizontalPodAutoscaler")[0]
assert h["spec"]["metrics"] == [metric] and h["spec"]["behavior"] == behavior
assert "Deployment" in render({"autoscaling": {"enabled": True}, "useDaemonSet": True}, fail=True)

print("autoscaling: passed")
