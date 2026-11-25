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
import yaml

chart = pathlib.Path(__file__).resolve().parents[2] / "charts/apisix"
for release, enabled, name in [("apisix", True, None), ("apisix", False, None),
                               ("prod", True, None), ("apisix", True, "gateway-account")]:
    args = ["helm", "template", release, str(chart), "--namespace", "gateway",
            "--set", "etcd.auth.token.enabled=false", "--set", "serviceAccount.create=true",
            "--set", f"ingress-controller.enabled={str(enabled).lower()}"]
    if name:
        args += ["--set", "serviceAccount.name=" + name]
    result = subprocess.run(args, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    docs = [doc for doc in yaml.safe_load_all(result.stdout) if doc]
    accounts = [doc["metadata"]["name"] for doc in docs if doc["kind"] == "ServiceAccount"]
    assert len(accounts) == len(set(accounts)), accounts
    workload = next(doc for doc in docs if doc["kind"] == "Deployment"
                    and doc["metadata"]["name"] == (release if release == "apisix" else "prod-apisix"))
    expected = name or ("apisix-gateway" if enabled and release == "apisix" else
                        ("apisix" if release == "apisix" else "prod-apisix"))
    assert workload["spec"]["template"]["spec"]["serviceAccountName"] == expected
    assert expected in accounts
print("serviceaccount_ownership: passed")
