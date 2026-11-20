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

def render_notes(values=None, release="my-apisix"):
    values = copy.deepcopy(values or {})
    values.setdefault("etcd", {}).setdefault("auth", {}).setdefault("token", {})["enabled"] = False
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as f:
        yaml.safe_dump(values or {}, f); f.flush()
        proc = subprocess.run(
            ["helm", "install", release, str(CHART), "-n", "gateway", "--dry-run=client", "--debug", "-f", f.name],
            capture_output=True, text=True,
        )
    assert proc.returncode == 0, proc.stderr
    return proc.stdout.split("NOTES:", 1)[1]

def config(docs):
    return yaml.safe_load(next(d["data"]["config.yaml"] for d in docs if d["kind"] == "ConfigMap" and "config.yaml" in d.get("data", {}) and "apisix" in yaml.safe_load(d["data"]["config.yaml"])))

for values in ({"apisix": {"deployment": {"mode": "decoupled"}}}, {"fullnameOverride": "custom"}, {"fullnameOverride": "x" * 63}, {"nameOverride": "gw"}, {"service": {"labelsOverride": {"custom": "selector"}}}):
    values.setdefault("apisix", {}).setdefault("deployment", {})["mode"] = "decoupled"
    values["serviceAccount"] = {"create": True}
    values["autoscaling"] = {"enabled": True}
    values["resources"] = {"requests": {"cpu": "100m", "memory": "128Mi"}}
    values["podDisruptionBudget"] = {"enabled": True}
    values["ingress"] = {"enabled": True, "hosts": [{"host": "gateway.test", "paths": ["/"]}]}
    docs = render(values)
    workloads = objects(docs, "Deployment")
    assert len(workloads) == 2
    assert len([d for d in objects(docs, "ConfigMap") if "config.yaml" in d.get("data", {})]) == 2
    names = {d["metadata"]["name"] for d in workloads}
    assert len(names) == 2
    assert {h["spec"]["scaleTargetRef"]["name"] for h in objects(docs, "HorizontalPodAutoscaler")} == names
    accounts = {d["metadata"]["name"] for d in objects(docs, "ServiceAccount")}
    for d in workloads:
        assert d["spec"]["template"]["spec"]["serviceAccountName"] in accounts
        assert d["spec"]["selector"]["matchLabels"].items() <= d["spec"]["template"]["metadata"]["labels"].items()
    for service in objects(docs, "Service"):
        if service["spec"].get("selector", {}).get("app.kubernetes.io/component") in ("control-plane", "data-plane"):
            assert sum(service["spec"]["selector"].items() <= d["spec"]["template"]["metadata"]["labels"].items() for d in workloads) == 1
    for p in objects(docs, "PodDisruptionBudget"):
        if p["metadata"]["name"] not in names:
            continue
        assert sum(p["spec"]["selector"]["matchLabels"].items() <= d["spec"]["template"]["metadata"]["labels"].items() for d in workloads) == 1
    services = {d["metadata"]["name"] for d in objects(docs, "Service")}
    for i in objects(docs, "Ingress"):
        for rule in i["spec"]["rules"]:
            for path in rule["http"]["paths"]:
                assert path["backend"]["service"]["name"] in services
    assert all(len(d["metadata"]["name"]) <= (253 if d["kind"] == "Secret" else 63) for d in docs)
default = render({})
assert len(objects(default, "Deployment")) == 1
assert objects(default, "Deployment")[0]["metadata"]["name"] == "my-apisix"
notes = render_notes({
    "apisix": {"deployment": {"mode": "decoupled"}},
    "service": {"type": "ClusterIP"},
})
assert all(part in notes for part in ('app.kubernetes.io/name=apisix', 'app.kubernetes.io/instance=my-apisix', 'app.kubernetes.io/component=data-plane'))
custom_notes = render_notes({
    "apisix": {"deployment": {"mode": "decoupled"}},
    "service": {"type": "ClusterIP", "labelsOverride": {"custom": "selector"}},
})
assert all(part in custom_notes for part in ("custom=selector", "app.kubernetes.io/component=data-plane"))
legacy_notes = render_notes({
    "service": {"type": "ClusterIP", "labelsOverride": {"custom": "selector"}},
})
assert "custom=selector" in legacy_notes
decoupled = render({"apisix": {"deployment": {"mode": "decoupled"}}})
plane_configs = {
    d["metadata"]["name"]: yaml.safe_load(d["data"]["config.yaml"])
    for d in objects(decoupled, "ConfigMap")
    if "config.yaml" in d.get("data", {})
}
assert plane_configs["my-apisix-control-plane"]["apisix"]["enable_admin"] is True
assert plane_configs["my-apisix-data-plane"]["apisix"]["enable_admin"] is False
standalone = render({"apisix": {"deployment": {"mode": "standalone"}}})
standalone_config = next(
    yaml.safe_load(d["data"]["config.yaml"])
    for d in objects(standalone, "ConfigMap")
    if "config.yaml" in d.get("data", {})
)
assert standalone_config["apisix"]["enable_admin"] is True
with_ingress = render({"apisix": {"deployment": {"mode": "decoupled"}}, "ingress-controller": {"enabled": True, "webhook": {"enabled": False}}})
assert {d["metadata"]["name"] for d in objects(with_ingress, "Deployment") if d["metadata"]["name"].endswith(("control-plane", "data-plane"))} == {"my-apisix-control-plane", "my-apisix-data-plane"}
legacy = render({"apisix": {"deployment": {"mode": "traditional"}}, "service": {"labelsOverride": {"legacy": "selector"}}})
assert len(objects(legacy, "Deployment")) == 1
long_legacy = render({"apisix": {"deployment": {"mode": "traditional"}}, "fullnameOverride": "x" * 63})
assert objects(long_legacy, "Deployment")[0]["metadata"]["name"] == "x" * 63
assert all(len(d["metadata"]["name"]) <= (253 if d["kind"] == "Secret" else 63) for d in long_legacy)
long_decoupled = render({
    "apisix": {"deployment": {"mode": "decoupled"}, "prometheus": {"enabled": True}},
    "fullnameOverride": "x" * 63,
})
assert all(len(d["metadata"]["name"]) <= (253 if d["kind"] == "Secret" else 63) for d in long_decoupled)
migrated = render({
    "apisix": {"deployment": {"mode": "decoupled"}},
    "service": {"gateway": {"name": "apisix-gateway"}},
    "ingress": {"enabled": True, "hosts": [{"host": "gateway.test", "paths": ["/"]}]},
})
gateway_services = [s for s in objects(migrated, "Service") if s["metadata"].get("labels", {}).get("app.kubernetes.io/service") == "apisix-gateway"]
assert len(gateway_services) == 1
assert gateway_services[0]["metadata"]["name"] == "apisix-gateway"
assert objects(migrated, "Ingress")[0]["spec"]["rules"][0]["http"]["paths"][0]["backend"]["service"]["name"] == "apisix-gateway"
admin_control_ingress = render({
    "apisix": {
        "deployment": {"mode": "decoupled"},
        "admin": {"ingress": {"enabled": True}},
    },
    "control": {"ingress": {"enabled": True}},
})
service_names = {s["metadata"]["name"] for s in objects(admin_control_ingress, "Service")}
for ingress in objects(admin_control_ingress, "Ingress"):
    assert ingress["metadata"]["name"] in service_names
    for rule in ingress["spec"]["rules"]:
        for path in rule["http"]["paths"]:
            backend = path["backend"].get("service", {})
            assert backend.get("name", path["backend"].get("serviceName")) in service_names
for key in ("controlPlane", "dataPlane"):
    docs = render({"apisix": {"deployment": {"mode": "decoupled", key: {"enabled": False}}}})
    assert len(objects(docs, "Deployment")) == 1
assert "at least one" in render({"apisix": {"deployment": {"mode": "decoupled", "controlPlane": {"enabled": False}, "dataPlane": {"enabled": False}}}}, fail=True)
docs = render({"service": {"labelsOverride": {"legacy": "selector"}}})
assert objects(legacy, "Deployment")[0]["spec"]["selector"]["matchLabels"] == {"legacy": "selector"}
docs = render({"apisix": {"deployment": {"mode": "decoupled"}}, "etcd": {"enabled": False}, "fullnameOverride": "custom", "externalEtcd": {"user": "test", "password": "test"}})
secrets = {d["metadata"]["name"] for d in objects(docs, "Secret")}
for d in objects(docs, "Deployment"):
    for env in d["spec"]["template"]["spec"]["containers"][0].get("env") or []:
        if env["name"] == "APISIX_ETCD_PASSWORD":
            assert env["valueFrom"]["secretKeyRef"]["name"] in secrets

# The upstream credential mechanism must stay release-scoped across both planes.
for credentials in ({}, {"secretName": "external-admin", "secretAdminKey": "token"}):
    docs = render({"apisix": {"deployment": {"mode": "decoupled"}, "admin": {"credentials": credentials}},
                   "ingress-controller": {"enabled": True}})
    services = {d["metadata"]["name"]: d for d in objects(docs, "Service")}
    proxy = objects(docs, "GatewayProxy")[0]
    admin = services[proxy["spec"]["provider"]["controlPlane"]["service"]["name"]]
    assert admin["spec"]["selector"]["app.kubernetes.io/component"] == "control-plane"
    secret = proxy["spec"]["provider"]["controlPlane"]["auth"]["adminKey"]["valueFrom"]["secretKeyRef"]
    assert secret["name"] == credentials.get("secretName", "my-apisix-admin-credentials")
    assert secret["key"] == credentials.get("secretAdminKey", "admin")
    for workload in objects(docs, "Deployment"):
        component = workload["spec"]["selector"]["matchLabels"].get("app.kubernetes.io/component")
        if component not in ("control-plane", "data-plane"):
            continue
        env = {e["name"]: e for e in workload["spec"]["template"]["spec"]["containers"][0].get("env") or []}
        if component == "control-plane":
            assert env["APISIX_ADMIN_KEY"]["valueFrom"]["secretKeyRef"] == secret
        else:
            assert "APISIX_ADMIN_KEY" not in env and "APISIX_VIEWER_KEY" not in env
for plane in ("controlPlane", "dataPlane"):
    docs = render({"apisix": {"deployment": {"mode": "decoupled", plane: {"enabled": False}}},
                   "ingress-controller": {"enabled": plane == "dataPlane"}})
    generated = [s for s in objects(docs, "Secret") if s["metadata"]["name"].endswith("-admin-credentials")]
    assert len(generated) == (0 if plane == "controlPlane" else 1)
print("topology: passed")
