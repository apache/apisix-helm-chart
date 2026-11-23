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
"""Render compatibility checks; run with Python 3, PyYAML and Helm 3/4."""
import copy
import os
import pathlib
import subprocess
import tempfile

import yaml

CHART = pathlib.Path(__file__).resolve().parents[2] / "charts/apisix"
PROFILE = yaml.safe_load((CHART / "examples/security-values.yaml").read_text())
DIRECTORIES = ["conf", "logs", "tmp", "client_body_temp", "proxy_temp",
               "fastcgi_temp", "uwsgi_temp", "scgi_temp"]
PATHS = ["/tmp" if d == "tmp" else "/usr/local/apisix/" + d for d in DIRECTORIES]


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


def legacy_values(image="apache/apisix:3.21.0-ubuntu"):
    """The issue #805 workaround owns all eight writable paths and its copy init."""
    values = copy.deepcopy(PROFILE)
    values["runtimeVolumes"]["enabled"] = False
    values["serviceAccount"] = {"automountServiceAccountToken": None}
    values["extraVolumes"] = [{"name": "legacy-" + d.replace("_", "-"),
                               "emptyDir": {}} for d in DIRECTORIES]
    values["extraVolumeMounts"] = [{"name": v["name"], "mountPath": path}
                                   for v, path in zip(values["extraVolumes"], PATHS)]
    values["extraInitContainers"] = [{
        "name": "legacy-copy", "image": image,
        "command": ["/bin/sh", "-ec", "cp -R /usr/local/apisix/conf/. /legacy-conf/; "
                    "cp -R /usr/local/apisix/logs/. /legacy-logs/"],
        "securityContext": copy.deepcopy(PROFILE["securityContext"]),
        "volumeMounts": [{"name": "legacy-" + d, "mountPath": "/legacy-" + d}
                         for d in ["conf", "logs"]],
    }]
    return values


def render(values=None, fail=False):
    values = copy.deepcopy(values or {})
    values.setdefault("etcd", {}).setdefault("auth", {}).setdefault("token", {})["enabled"] = False
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as f:
        yaml.safe_dump(values, f)
        f.flush()
        proc = subprocess.run([os.environ.get("HELM", "helm"), "template", "security",
                               str(CHART), "-n", "gateway", "-f", f.name],
                              capture_output=True, text=True)
    if fail:
        assert proc.returncode, "Expected invalid values to fail"
        return proc.stderr
    assert proc.returncode == 0, proc.stderr
    docs = [d for d in yaml.load_all(proc.stdout, Loader=StrictLoader) if d]
    ids = [(d["apiVersion"], d["kind"], d["metadata"].get("namespace", "gateway"),
            d["metadata"]["name"]) for d in docs]
    assert len(ids) == len(set(ids)), "Duplicate resource identities"
    pod = next(d["spec"]["template"]["spec"] for d in docs
               if d["kind"] in ["Deployment", "DaemonSet"])
    volumes = [v["name"] for v in pod["volumes"]]
    assert len(volumes) == len(set(volumes)), "Duplicate volume names"
    for container in pod["containers"] + (pod.get("initContainers") or []):
        mounts = container.get("volumeMounts", [])
        paths = [os.path.normpath(m["mountPath"]) for m in mounts]
        assert len(paths) == len(set(paths)), "Duplicate mountPaths: " + container["name"]
        assert all(m["name"] in volumes for m in mounts), "Missing volume reference"
    return docs, pod


def main():
    _, pod = render()
    assert "securityContext" not in pod
    assert "securityContext" not in pod["containers"][0]
    assert "automountServiceAccountToken" not in pod
    assert "securityContext" not in pod["initContainers"][0]
    assert not any(v["name"].startswith("runtime-") for v in pod["volumes"])
    # Old release values (including --reuse-values) may not contain the new map.
    _, inherited = render({"runtimeVolumes": None})
    assert inherited == pod
    # Existing readOnlyRootFilesystem values must not implicitly enable new mounts.
    _, pod = render({"securityContext": {"readOnlyRootFilesystem": True}})
    assert not any(v["name"].startswith("runtime-") for v in pod["volumes"])
    for daemonset in [False, True]:
        for bundled_etcd in [False, True]:
            values = copy.deepcopy(PROFILE)
            values.update({"useDaemonSet": daemonset, "etcd": {"enabled": bundled_etcd},
                           "serviceAccount": {"create": True, "automountServiceAccountToken": False}})
            docs, pod = render(values)
            container = pod["containers"][0]
            assert pod["securityContext"]["runAsUser"] == 636
            assert container["securityContext"]["readOnlyRootFilesystem"] is True
            assert pod["automountServiceAccountToken"] is False
            account = next(d for d in docs if d["kind"] == "ServiceAccount"
                           and d["metadata"]["name"] == pod["serviceAccountName"])
            assert account["automountServiceAccountToken"] is False
            assert account["metadata"]["name"] == pod["serviceAccountName"]
            assert set(PATHS) <= {m["mountPath"] for m in container["volumeMounts"]}
            prepare = next(c for c in pod["initContainers"] if c["name"] == "prepare-runtime")
            assert prepare["image"] == container["image"]
            assert {m["name"] for m in prepare["volumeMounts"]} == {"runtime-conf", "runtime-logs"}
            if bundled_etcd:
                wait = next(c for c in pod["initContainers"] if c["name"] == "wait-etcd")
                assert wait["securityContext"]["runAsUser"] == 636
    values = copy.deepcopy(PROFILE)
    values["image"] = {"repository": "registry.example.test/apisix", "tag": "custom"}
    _, pod = render(values)
    prepare = next(c for c in pod["initContainers"] if c["name"] == "prepare-runtime")
    assert prepare["image"] == pod["containers"][0]["image"]
    for enabled in [False, True]:
        values = legacy_values()
        values["runtimeVolumes"]["enabled"] = enabled
        _, pod = render(values)
        assert not any(v["name"].startswith("runtime-") for v in pod["volumes"])
        assert not any(c["name"] == "prepare-runtime" for c in pod["initContainers"])
        assert values["extraInitContainers"][0] == pod["initContainers"][-1]
        assert "automountServiceAccountToken" not in pod
    # Partial overrides leave preparation only for chart-owned config/log directories.
    for overridden in ["conf", "logs"]:
        values = copy.deepcopy(PROFILE)
        values["extraVolumes"] = [{"name": "custom", "emptyDir": {}}]
        values["extraVolumeMounts"] = [{"name": "custom", "mountPath": "/usr/local/apisix/" + overridden + "/"}]
        _, pod = render(values)
        prepare = next(c for c in pod["initContainers"] if c["name"] == "prepare-runtime")
        other = "logs" if overridden == "conf" else "conf"
        assert [m["name"] for m in prepare["volumeMounts"]] == ["runtime-" + other]
        assert "/usr/local/apisix/" + overridden + "/." not in prepare["args"][0]
    for created in [False, True]:
        for token in [None, False, True]:
            docs, pod = render({"serviceAccount": {"create": created, "automountServiceAccountToken": token}})
            assert ("automountServiceAccountToken" in pod) == (token is not None)
            if token is not None:
                assert pod["automountServiceAccountToken"] is token
            for account in (d for d in docs if d["kind"] == "ServiceAccount"
                            and d["metadata"]["name"] == pod["serviceAccountName"]):
                assert ("automountServiceAccountToken" in account) == (token is not None)
                if token is not None:
                    assert account["automountServiceAccountToken"] is token
    error = render({"runtimeVolumes": {"enabled": True}, "extraVolumes": [
        {"name": "runtime-conf", "emptyDir": {}}]}, fail=True)
    assert "conflicts with an automatic runtime volume" in error
    print("security: compatibility, opt-in volumes and ServiceAccount checks passed")


if __name__ == "__main__":
    main()
