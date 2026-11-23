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
"""Exercise real Kubernetes volumes, token inheritance and upgrades; needs kind/helm."""
import copy
import json
import os
import pathlib
import runpy
import subprocess
import tempfile
import uuid

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPERS = runpy.run_path(str(ROOT / "test/render/security.py"))
CHART = str(ROOT / "charts/apisix")
HELM = os.environ.get("HELM", "helm")
BASE = os.environ.get("SECURITY_BASE_CHART", CHART)
PROFILE = HELPERS["PROFILE"]
NAMESPACE = "security-" + uuid.uuid4().hex[:8]


def run(*args):
    proc = subprocess.run(args, capture_output=True, text=True, timeout=360)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    return proc.stdout


def kube(*args):
    return run("kubectl", "-n", NAMESPACE, *args)


def obj(kind, name):
    return json.loads(kube("get", kind, name, "-o", "json"))


def apply(release, chart, values, upgrade=False):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as f:
        yaml.safe_dump(values, f)
        f.flush()
        run(HELM, "upgrade" if upgrade else "install", release, chart,
            "-n", NAMESPACE, "-f", f.name, "--wait", "--timeout", "5m")
    return obj("deployment", release + "-apisix")


def verify(release, token):
    pods = json.loads(kube("get", "pods", "-l", "app.kubernetes.io/instance=" + release,
                           "-o", "json"))["items"]
    pods = [p for p in pods if not p["metadata"].get("deletionTimestamp")]
    assert len(pods) == 1, [p["metadata"]["name"] for p in pods]
    pod = pods[0]
    assert pod["status"]["containerStatuses"][0]["ready"]
    assert pod["status"]["containerStatuses"][0]["restartCount"] == 0
    assert all(c["state"]["terminated"]["exitCode"] == 0
               for c in pod["status"].get("initContainerStatuses", []))
    name = pod["metadata"]["name"]
    if token:
        token_test = "test -f /var/run/secrets/kubernetes.io/serviceaccount/token"
    else:
        token_test = "test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token"
    kube("exec", name, "-c", "apisix", "--", "sh", "-ec", token_test)
    # Test actual volume permissions and readonly enforcement, not only Pod fields.
    if pod["spec"]["containers"][0].get("securityContext", {}).get("readOnlyRootFilesystem"):
        assert kube("exec", name, "-c", "apisix", "--", "id", "-u").strip() == "636"
        paths = " ".join(HELPERS["PATHS"])
        kube("exec", name, "-c", "apisix", "--", "sh", "-ec",
             "for d in " + paths + "; do touch \"$d/.security-write-check\"; "
             "rm \"$d/.security-write-check\"; done; "
             "if touch /security-root-write-check 2>/dev/null; then exit 1; fi")
    lua = ("local s=ngx.socket.tcp(); assert(s:connect('127.0.0.1',9080)); "
           "assert(s:send('GET /security-test HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n')); "
           "local response=s:receive('*a'); assert(response:find('200 OK',1,true),response); "
           "assert(response:find('security-ok',1,true),response)")
    kube("exec", name, "-c", "apisix", "--", "/usr/local/openresty/bin/resty", "-e", lua)
    print(release + ": route, writable volumes, permissions and token verified", flush=True)


def main():
    values = yaml.safe_load((ROOT / "charts/apisix/values.yaml").read_text())
    metadata = yaml.safe_load((ROOT / "charts/apisix/Chart.yaml").read_text())
    image = values["image"]["repository"]
    if values["image"].get("digest"):
        image += "@" + values["image"]["digest"]
    else:
        image += ":" + (values["image"].get("tag") or str(metadata["appVersion"]))
    common = {
        "etcd": {"enabled": False}, "image": {"pullPolicy": "IfNotPresent"},
        "lifecycle": {}, "terminationGracePeriodSeconds": 5,
        "apisix": {"deployment": {"mode": "standalone", "standalone": {"config":
            "routes:\n  - uri: /security-test\n    plugins:\n      serverless-pre-function:\n"
            "        phase: rewrite\n        functions:\n"
            "          - 'return function(conf, ctx) ngx.say(\"security-ok\"); ngx.exit(200) end'\n#END\n"}}},
    }
    run("kubectl", "create", "namespace", NAMESPACE)
    try:
        # Existing #805 workaround, first installed using the actual base chart.
        legacy = HELPERS["legacy_values"](image)
        legacy.update(copy.deepcopy(common))
        before = apply("legacy", BASE, legacy)
        verify("legacy", True)
        service = obj("service", "legacy-apisix-gateway")
        legacy["runtimeVolumes"]["enabled"] = True
        after = apply("legacy", CHART, legacy, upgrade=True)
        assert before["spec"]["template"]["spec"]["securityContext"] == after["spec"]["template"]["spec"]["securityContext"]
        assert "automountServiceAccountToken" not in after["spec"]["template"]["spec"]
        service_after = obj("service", "legacy-apisix-gateway")
        assert service["metadata"]["uid"] == service_after["metadata"]["uid"]
        assert service["spec"] == service_after["spec"]
        verify("legacy", True)
        print("base-chart upgrade retained Service identity and legacy mounts", flush=True)
        # Default null also preserves an external ServiceAccount that disables tokens.
        kube("patch", "serviceaccount", "default", "--type=merge", "-p",
             '{"automountServiceAccountToken":false}')
        plain = copy.deepcopy(common)
        plain["apisix"]["deployment"]["standalone"]["existingConfigMap"] = "apisix.yaml"
        apply("plain", BASE, plain)
        verify("plain", False)
        after = apply("plain", CHART, plain, upgrade=True)
        spec = after["spec"]["template"]["spec"]
        assert "securityContext" not in spec
        assert "securityContext" not in spec["containers"][0]
        assert "automountServiceAccountToken" not in spec
        verify("plain", False)
        # New opt-in profile exercises chart-managed volumes and a chart-created SA.
        secure = copy.deepcopy(PROFILE)
        secure.update(copy.deepcopy(common))
        secure["apisix"]["deployment"]["standalone"]["existingConfigMap"] = "apisix.yaml"
        secure["serviceAccount"]["create"] = True
        apply("secure", CHART, secure)
        account = obj("serviceaccount", "secure-apisix")
        assert account["automountServiceAccountToken"] is False
        verify("secure", False)
        print("security Kubernetes upgrade tests passed", flush=True)
    finally:
        if os.environ.get("KEEP_NAMESPACES") != "1":
            kube("delete", "namespace", NAMESPACE, "--wait=false")


if __name__ == "__main__":
    main()
