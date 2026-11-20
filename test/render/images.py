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
    return yaml.safe_load(next(d["data"]["config.yaml"] for d in docs if d["kind"] == "ConfigMap" and "config.yaml" in d.get("data", {})))

defaults = yaml.safe_load((CHART / "values.yaml").read_text())
metadata = yaml.safe_load((CHART / "Chart.yaml").read_text())
assert defaults["image"]["tag"] == str(metadata["appVersion"]) + "-ubuntu"
docs = render()
assert objects(docs, "StatefulSet"), "Default install must retain bundled etcd"
c = objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["containers"][0]
assert c["image"] == "apache/apisix@sha256:398ded33cde36b60ca7f5dd58e8d8132b41afffaf7ac4bb72db8491fc316fe55"
e = objects(docs, "StatefulSet")[0]["spec"]["template"]["spec"]["containers"][0]
assert e["image"].endswith("@sha256:db0fec3c3fa1d508faf8d1b03e4976ea54e4e3f368335d66f4b1313662f37483")
wait = next(c for c in objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["initContainers"] if c["name"] == "wait-etcd")
assert wait["image"] == "busybox@sha256:141c253bc4c3fd0a201d32dc1f493bcf3fff003b6df416dea4f41046e0f37d47"
docs = render({"initContainer": {"digest": "", "tag": "custom"}})
wait = next(c for c in objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["initContainers"] if c["name"] == "wait-etcd")
assert wait["image"] == "busybox:custom"
docs = render({"etcd": {"enabled": False}, "externalEtcd": {"host": ["http://etcd.storage.svc:2379"]}})
assert not objects(docs, "StatefulSet")
assert config(docs)["deployment"]["etcd"]["host"] == ["http://etcd.storage.svc:2379"]
docs = render({"image": {"digest": "", "tag": "custom"}})
assert objects(docs, "Deployment")[0]["spec"]["template"]["spec"]["containers"][0]["image"] == "apache/apisix:custom"

print("images: passed")
