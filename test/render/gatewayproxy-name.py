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
import unittest

import yaml


class GatewayProxyNameTest(unittest.TestCase):
    def test_names(self):
        chart = Path(__file__).resolve().parents[2] / "charts/apisix-ingress-controller"
        release = "gatewayproxy-test"
        cases = [
            ("unset", None, None),
            ("empty", "", None),
            ("custom", "custom", "custom"),
            ("release-template", "{{ .Release.Name }}-config", release + "-config"),
            ("empty-template", '{{ "" }}', None),
            ("numeric", "123", "123"),
            ("leading-zero", "00123", "00123"),
            ("boolean-like", "true", "true"),
            ("null-like", "null", "null"),
            ("numeric-template", '{{ "123" }}', "123"),
        ]
        with tempfile.TemporaryDirectory() as directory:
            values_file = Path(directory) / "values.yaml"
            for create_default in (False, True):
                for label, name, rendered in cases:
                    with self.subTest(createDefault=create_default, name=label):
                        values = {"gatewayProxy": {"createDefault": create_default}}
                        if name is not None:
                            values["gatewayProxy"]["name"] = name
                        values_file.write_text(yaml.safe_dump(values))
                        result = subprocess.run(
                            [os.environ.get("HELM_BIN", "helm"), "template", release,
                             str(chart), "--values", str(values_file)],
                            capture_output=True, text=True,
                        )
                        self.assertEqual(result.returncode, 0, result.stderr)
                        docs = [doc for doc in yaml.safe_load_all(result.stdout) if doc]
                        classes = [doc for doc in docs if doc["kind"] == "IngressClass"]
                        proxies = [doc for doc in docs if doc["kind"] == "GatewayProxy"]
                        self.assertEqual(len(classes), 1)
                        self.assertEqual(len(proxies), int(create_default))
                        expected = rendered or (release + "-config" if create_default else None)
                        if expected is None:
                            self.assertNotIn("parameters", classes[0]["spec"])
                        else:
                            reference = classes[0]["spec"]["parameters"]["name"]
                            self.assertIsInstance(reference, str)
                            self.assertEqual(reference, expected)
                        if create_default:
                            actual = proxies[0]["metadata"]["name"]
                            self.assertIsInstance(actual, str)
                            self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
