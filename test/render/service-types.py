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
import os
from pathlib import Path
import subprocess
import tempfile

import yaml


ROOT = Path(__file__).resolve().parents[2]
CHART = ROOT / "charts/apisix"
HELM = os.environ.get("HELM_BIN", "helm")


def render(values):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as values_file:
        yaml.safe_dump(values, values_file)
        values_file.flush()
        result = subprocess.run(
            [HELM, "template", "service-types", str(CHART),
             "--set", "apisix.prometheus.enabled=true",
             "--values", values_file.name],
            capture_output=True, text=True, check=False,
        )
    if result.returncode:
        raise AssertionError(result.stderr)
    return [doc for doc in yaml.safe_load_all(result.stdout) if doc]


def metrics_service(docs):
    return next(
        doc for doc in docs
        if doc.get("kind") == "Service"
        and doc.get("metadata", {}).get("name", "").endswith("-prometheus-metrics")
    )


def main():
    assert metrics_service(render({}))["spec"]["type"] == "ClusterIP"
    assert metrics_service(render({"apisix": {"prometheus": {"service": {"type": "NodePort"}}}}))["spec"]["type"] == "NodePort"
    print("service_types: passed")


if __name__ == "__main__":
    main()
