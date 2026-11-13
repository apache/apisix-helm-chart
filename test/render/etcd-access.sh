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
# Render tests for access to the bundled etcd: its NetworkPolicy, the client
# label of the APISIX pods, and the root password that APISIX connects with.
# Needs helm and yq (https://github.com/mikefarah/yq, v4). Run from the
# repository root after `helm dependency build charts/apisix`.
# Set HELM to use another helm binary.

set -uo pipefail

HELM=${HELM:-helm}
for tool in "${HELM%% *}" yq; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 2; }
done
CHART=charts/apisix
# keys that are not the public defaults, so that the chart renders without a cluster
KEYS=(--set apisix.admin.credentials.admin=AdminKeyForRenderTests1234567890
      --set apisix.admin.credentials.viewer=ViewerKeyForRenderTests123456789)

passed=0
failed=0
OUT=""
ERR=""

check() { # check <description> <command...>
  local desc=$1; shift
  if "$@"; then
    echo "ok   - $desc"; passed=$((passed + 1))
  else
    echo "FAIL - $desc"; failed=$((failed + 1))
  fi
}

render() { # render <release> [helm args...]; sets OUT and ERR, returns helm's exit code
  local release=$1 errfile rc; shift
  errfile=$(mktemp)
  OUT=$($HELM template "$release" "$CHART" --namespace demo "${KEYS[@]}" "$@" 2>"$errfile")
  rc=$?
  ERR=$(cat "$errfile"); rm -f "$errfile"
  [ $rc -eq 0 ] || echo "       $ERR" >&2
  return $rc
}

is() { [ "$1" = "$2" ] || { echo "       expected '$2', got '$1'" >&2; return 1; }; }
pod_label() { # pod_label <label>: the label's value on the APISIX pods
  yq "select(.kind == \"Deployment\" or .kind == \"DaemonSet\") | .spec.template.metadata.labels[\"$1\"]" <<<"$OUT"
}
pod_labels() { yq 'select(.kind == "Deployment" or .kind == "DaemonSet") | .spec.template.metadata.labels | keys | join(",")' <<<"$OUT"; }
job_label() { # job_label <Job or CronJob name> <label>: the label's value on the job's pods
  yq "select(.metadata.name == \"$1\") | (.spec.template.metadata.labels // .spec.jobTemplate.spec.template.metadata.labels)[\"$2\"]" <<<"$OUT"
}
policy_from() { # the "from" rules of the client port of the etcd NetworkPolicy, as JSON
  yq -o json -I0 "select(.kind == \"NetworkPolicy\" and .metadata.name == \"$1\") | .spec.ingress[0].from" <<<"$OUT"
}
password_ref() { # "<secret>/<key>" that APISIX reads its etcd password from
  yq 'select(.kind == "Deployment") | .spec.template.spec.containers[] | select(.name == "apisix") | .env[] | select(.name == "APISIX_ETCD_PASSWORD") | .valueFrom.secretKeyRef | .name + "/" + .key' <<<"$OUT"
}
etcd_password_ref() { # "<secret>/<key>" that etcd reads its root password from: a file of a projected Secret
  local sts secret file
  sts=$(yq 'select(.kind == "StatefulSet")' <<<"$OUT")
  secret=$(yq '.spec.template.spec.volumes[] | select(.name == "etcd-secrets") | .projected.sources[0].secret.name' <<<"$sts")
  file=$(yq '.spec.template.spec.containers[] | select(.name == "etcd") | .env[] | select(.name == "ETCD_ROOT_PASSWORD_FILE") | .value' <<<"$sts")
  echo "$secret/${file##*/}"
}
etcd_config() { yq 'select(.kind == "ConfigMap" and .data["config.yaml"] != null) | .data["config.yaml"]' <<<"$OUT" | yq "$1"; }
secret_exists() { [ -n "$(yq "select(.kind == \"Secret\" and .metadata.name == \"$1\") | .metadata.name" <<<"$OUT")" ]; }
no_secret() { ! secret_exists "$1"; }

# --- the NetworkPolicy and the client label -------------------------------------

check "default: renders" render apisix
check "default: the APISIX pods carry the etcd client label" is "$(pod_label apisix-etcd-client)" true
check "default: etcd accepts only the client label and its own pods" is "$(policy_from apisix-etcd)" \
  '[{"podSelector":{"matchLabels":{"apisix-etcd-client":"true"}}},{"podSelector":{"matchLabels":{"app.kubernetes.io/instance":"apisix","app.kubernetes.io/name":"etcd","app.kubernetes.io/component":"etcd"}}}]'

check "default: the etcd chart's pre-upgrade job carries the label too" is "$(job_label apisix-etcd-pre-upgrade apisix-etcd-client)" true

check "etcd jobs: renders" render apisix --set etcd.disasterRecovery.enabled=true \
  --set etcd.disasterRecovery.pvc.existingClaim=snapshots --set etcd.defrag.enabled=true
check "etcd jobs: the snapshot job carries the label" is "$(job_label apisix-etcd-snapshotter apisix-etcd-client)" true
check "etcd jobs: the defragmentation job carries the label" is "$(job_label apisix-etcd-defrag apisix-etcd-client)" true

check "allowExternal: renders" render apisix --set etcd.networkPolicy.allowExternal=true
check "allowExternal: the client port accepts any pod" is "$(policy_from apisix-etcd)" null
check "allowExternal: the label is still set" is "$(pod_label apisix-etcd-client)" true

check "fullnameOverride: renders" render apisix --set etcd.fullnameOverride=kv
check "fullnameOverride: the label follows the etcd name" is "$(pod_label kv-client)" true
check "fullnameOverride: and so does the policy" is "$(policy_from kv | yq -p json '.[0].podSelector.matchLabels | keys | join(",")')" kv-client
check "fullnameOverride: and the pre-upgrade job's label" is "$(job_label kv-pre-upgrade kv-client)" true

check "release name with etcd in it: renders" render my-etcd
check "release name with etcd in it: the label uses the etcd chart's name" is "$(pod_label my-etcd-client)" true

check "external etcd: renders" render apisix --set etcd.enabled=false --set 'externalEtcd.host[0]=http://etcd.example:2379'
check "external etcd: no client label" is "$(pod_labels)" "app.kubernetes.io/name,app.kubernetes.io/instance"

check "DaemonSet: renders" render apisix --set useDaemonSet=true
check "DaemonSet: the pods carry the etcd client label" is "$(pod_label apisix-etcd-client)" true

# --- the root password ---------------------------------------------------------------

check "default: no etcd user for APISIX" is "$(etcd_config '.deployment.etcd | has("user")')" false
check "default: no password variable" is "$(password_ref)" ""

check "RBAC, generated password: renders" render apisix --set etcd.auth.rbac.create=true
check "RBAC, generated password: APISIX reads the etcd chart's Secret" is "$(password_ref)" apisix-etcd/etcd-root-password
check "RBAC, generated password: the same one as etcd" is "$(etcd_password_ref)" apisix-etcd/etcd-root-password
check "RBAC, generated password: the Secret is rendered" secret_exists apisix-etcd
check "RBAC: APISIX connects as root" is "$(etcd_config '.deployment.etcd.user')" root

check "RBAC, existing Secret: renders" render apisix --set etcd.auth.rbac.create=true --set etcd.auth.rbac.existingSecret=etcd-auth
check "RBAC, existing Secret: APISIX reads it" is "$(password_ref)" etcd-auth/etcd-root-password
check "RBAC, existing Secret: the same one as etcd" is "$(etcd_password_ref)" etcd-auth/etcd-root-password
check "RBAC, existing Secret: no Secret is generated" no_secret apisix-etcd

check "RBAC, existing Secret with its own key: renders" render apisix --set etcd.auth.rbac.create=true \
  --set etcd.auth.rbac.existingSecret=etcd-auth --set etcd.auth.rbac.existingSecretPasswordKey=password
check "RBAC, existing Secret with its own key: APISIX reads that key" is "$(password_ref)" etcd-auth/password
check "RBAC, existing Secret with its own key: the same one as etcd" is "$(etcd_password_ref)" etcd-auth/password

echo
echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
