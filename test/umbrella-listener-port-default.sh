#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

# Exercise the published dependency, not the sibling controller chart.
chart="charts/apisix"
render_config() {
  helm template test "$chart" --set ingress-controller.enabled=true \
    --show-only charts/ingress-controller/templates/configmap.yaml "$@"
}

config=$(render_config)
grep -q '^    listener_port_match_mode: off$' <<<"$config"
for mode in off auto explicit; do
  config=$(render_config --set "ingress-controller.config.listenerPortMatchMode=$mode")
  grep -q "^    listener_port_match_mode: $mode$" <<<"$config"
done
