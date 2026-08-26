#!/usr/bin/env bash

set -euo pipefail

chart="charts/apisix-ingress-controller"

default_config=$(helm template test "$chart" --show-only templates/configmap.yaml)
grep -q '^    listener_port_match_mode: off$' <<<"$default_config"

auto_config=$(helm template test "$chart" \
  --show-only templates/configmap.yaml \
  --set config.listenerPortMatchMode=auto)
grep -q '^    listener_port_match_mode: auto$' <<<"$auto_config"
