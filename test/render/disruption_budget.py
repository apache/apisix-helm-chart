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

for field, value in (("minAvailable", 0), ("minAvailable", "90%"), ("maxUnavailable", 0), ("maxUnavailable", "25%")):
    values = {"podDisruptionBudget": {"enabled": True, "minAvailable": None, "maxUnavailable": None}}
    values["podDisruptionBudget"][field] = value
    docs = render(values)
    p = next(p for p in objects(docs, "PodDisruptionBudget") if p["metadata"]["name"] == "my-apisix")
    assert p["spec"][field] == value
    assert ("minAvailable" in p["spec"]) + ("maxUnavailable" in p["spec"]) == 1
assert "exactly one" in render({"podDisruptionBudget": {"enabled": True, "minAvailable": 1, "maxUnavailable": 1}}, fail=True)
assert "at most 100" in render({"podDisruptionBudget": {"enabled": True, "minAvailable": "101%"}}, fail=True)

# Replaying old effective defaults must preserve the existing eviction budget.
docs = render({"podDisruptionBudget": {"enabled": True, "minAvailable": "90%", "maxUnavailable": 1}})
pdb = next(p for p in objects(docs, "PodDisruptionBudget") if p["metadata"]["name"] == "my-apisix")
assert pdb["spec"]["minAvailable"] == "90%"
assert "maxUnavailable" not in pdb["spec"]
print("disruption_budget: passed")
