#!/usr/bin/env bash
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
# End-to-end tests for access to the bundled etcd, against a real cluster whose
# network plugin enforces NetworkPolicies (kind's default one does). Needs
# kubectl, helm and curl. Run from the repository root after
# `helm dependency build charts/apisix`.
#
#   KEEP_NAMESPACES=1  keep the test namespace for debugging

set -uo pipefail

HELM=${HELM:-helm}
CHART=${CHART:-charts/apisix}
NS=etcd-e2e
random_letters() { LC_ALL=C tr -dc 'A-Za-z' </dev/urandom | head -c "$1"; }
ADMIN_KEY=$(random_letters 32)
ROOT_PASSWORD=$(random_letters 24)
COMMON=(--set apisix.admin.credentials.admin="$ADMIN_KEY"
        --set etcd.replicaCount=1
        --wait --timeout 10m)
ADMIN_PORT=19190
PROBE_IMAGE=busybox:1.28

passed=0
failed=0
PF_PIDS=()

cleanup() {
  stop_port_forwards
  if [ "${KEEP_NAMESPACES:-}" != 1 ]; then
    $HELM uninstall --namespace "$NS" apisix --wait >/dev/null 2>&1
    kubectl delete namespace "$NS" --wait=false >/dev/null 2>&1
  fi
}
trap cleanup EXIT

check() { # check <description> <command...>
  local desc=$1; shift
  if "$@"; then
    echo "ok   - $desc"; passed=$((passed + 1))
  else
    echo "FAIL - $desc"; failed=$((failed + 1))
  fi
}

is() { [ "$1" = "$2" ] || { echo "       expected '$2', got '$1'" >&2; return 1; }; }

wait_for() { # wait_for <seconds> <command...>: retry until the command succeeds
  local deadline=$((SECONDS + $1)); shift
  until "$@" >/dev/null 2>&1; do
    [ "$SECONDS" -ge "$deadline" ] && return 1
    sleep 2
  done
}

stop_port_forwards() {
  for pid in "${PF_PIDS[@]:-}"; do [ -n "$pid" ] && { kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; }; done
  PF_PIDS=()
}

connect() { # port-forward the Admin API of the ready release
  stop_port_forwards
  kubectl --namespace "$NS" rollout status deployment/apisix --timeout=300s >/dev/null
  kubectl --namespace "$NS" port-forward svc/apisix-admin "$ADMIN_PORT:9180" >/dev/null 2>&1 &
  PF_PIDS+=($!)
  wait_for 60 curl -s -o /dev/null "http://127.0.0.1:$ADMIN_PORT/"
}

writes() { # writes <route id>: the Admin API stores a route, so APISIX can write to etcd
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "http://127.0.0.1:$ADMIN_PORT/apisix/admin/routes/$1" \
    -H "X-API-KEY: $ADMIN_KEY" -d "{\"uri\":\"/$1\",\"upstream\":{\"nodes\":{\"127.0.0.1:1980\":1}}}")
  case "$code" in 200|201) return 0 ;; *) echo "       status $code" >&2; return 1 ;; esac
}

probe_etcd() { # probe_etcd <pod name prefix> [label]: REACHED, TIMEOUT, or the error of a new pod that requests etcd
  local name="$1-$RANDOM$RANDOM"
  local args=(--namespace "$NS" run "$name" --image="$PROBE_IMAGE" --restart=Never)
  [ $# -ge 2 ] && args+=(--labels="$2")
  kubectl "${args[@]}" --command -- sh -c '
    out=$(wget -q -T 5 -O - http://apisix-etcd:2379/version 2>&1)
    case "$out" in
      *etcdserver*) echo REACHED ;;
      *"timed out"*) echo TIMEOUT ;;
      *) echo "ERROR: $out" ;;
    esac' >/dev/null
  kubectl --namespace "$NS" wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$name" --timeout=90s >/dev/null 2>&1
  kubectl --namespace "$NS" logs "$name" 2>/dev/null | tail -1
}
reaches_etcd() { is "$(probe_etcd "$@")" REACHED; }
# a NetworkPolicy drops the connection, so the request times out; any other
# failure means the probe itself is broken
blocked() { is "$(probe_etcd "$@")" TIMEOUT; }

routes_in_etcd() { # routes_in_etcd [etcdctl flags...]: number of route keys etcdctl in the etcd pod can list
  kubectl --namespace "$NS" exec apisix-etcd-0 -- env -u ETCDCTL_USER etcdctl "$@" get /apisix/routes --prefix --keys-only 2>/dev/null |
    grep -c '^/apisix/routes/'
}
refuses_anonymous() { is "$(routes_in_etcd)" 0; }

upgrade() { $HELM upgrade apisix "$CHART" --namespace "$NS" "${COMMON[@]}" "$@" >/dev/null; }

echo "# the bundled etcd accepts only the APISIX pods"
kubectl create namespace "$NS" >/dev/null
$HELM install apisix "$CHART" --namespace "$NS" "${COMMON[@]}" >/dev/null
check "install with the defaults succeeds" is $? 0
check "connected to the Admin API" connect
check "APISIX writes to etcd" writes first
check "etcd lists the route without credentials, before RBAC" is "$(routes_in_etcd)" 1
check "a pod with the client label can reach etcd" reaches_etcd labelled apisix-etcd-client=true
check "a pod without the client label cannot" blocked outsider

check "upgrade with etcd.networkPolicy.allowExternal=true succeeds" upgrade --set etcd.networkPolicy.allowExternal=true
check "then a pod without the label can reach etcd" wait_for 60 reaches_etcd outsider
check "upgrade back to the default succeeds" upgrade

echo "# turn on etcd authentication for the existing release"
kubectl --namespace "$NS" create secret generic apisix-etcd-auth --from-literal=etcd-root-password="$ROOT_PASSWORD" >/dev/null
check "upgrade with RBAC and the root password in an existing Secret succeeds" \
  upgrade --set etcd.auth.rbac.create=true --set etcd.auth.rbac.existingSecret=apisix-etcd-auth
check "connected to the Admin API" connect
check "APISIX writes to etcd with the password" writes second
check "etcd refuses a client without credentials" refuses_anonymous
check "etcd accepts root with the password" is "$(routes_in_etcd --user "root:$ROOT_PASSWORD")" 2
check "a later upgrade with the same values succeeds" \
  upgrade --set etcd.auth.rbac.create=true --set etcd.auth.rbac.existingSecret=apisix-etcd-auth
check "connected to the Admin API" connect
check "APISIX still writes to etcd" writes third

echo
echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
