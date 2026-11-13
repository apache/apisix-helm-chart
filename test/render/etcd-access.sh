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
# Kubernetes accepts only strings as label values, and yq prints the boolean
# true like the string "true", so the label helpers print only strings
pod_label() { # pod_label <label>: the label's value on the APISIX pods, if it is a string
  yq "select(.kind == \"Deployment\" or .kind == \"DaemonSet\") | .spec.template.metadata.labels[\"$1\"] | select(type == \"!!str\")" <<<"$OUT"
}
pod_labels() { yq 'select(.kind == "Deployment" or .kind == "DaemonSet") | .spec.template.metadata.labels | keys | join(",")' <<<"$OUT"; }
pod_label_type() { # pod_label_type <label>: the YAML type of the label's value on the APISIX pods
  yq "select(.kind == \"Deployment\" or .kind == \"DaemonSet\") | .spec.template.metadata.labels[\"$1\"] | type" <<<"$OUT"
}
job_label() { # job_label <Job or CronJob name> <label>: the label's value on the job's pods, if it is a string
  yq "select(.metadata.name == \"$1\") | (.spec.template.metadata.labels // .spec.jobTemplate.spec.template.metadata.labels)[\"$2\"] | select(type == \"!!str\")" <<<"$OUT"
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
policy() { yq "select(.kind == \"NetworkPolicy\" and .metadata.name == \"$1\")" <<<"$OUT"; }
open_client_rules() { # open_client_rules <policy name>: ingress rules that admit any pod to the client or peer port
  policy "$1" | yq '[.spec.ingress[] | select((.from // []) | length == 0)
    | select((.ports // [{"port": 2379}]) | map(.port) | any_c(. == 2379 or . == 2380))] | length'
}
longest_label() { # the longest label key of the pods of the chart and of the etcd chart's jobs
  yq 'select(.kind == "Deployment" or .kind == "DaemonSet" or .kind == "Job") | .spec.template.metadata.labels | keys | .[]' <<<"$OUT" |
    awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }'
}
fails_with() { # fails_with <message part> <release> [helm args...]
  local text=$1; shift
  if render "$@" 2>/dev/null; then echo "       rendered without an error" >&2; return 1; fi
  grep -qF -- "$text" <<<"$ERR" || { echo "       error was: $ERR" >&2; return 1; }
}
etcd_config() { yq 'select(.kind == "ConfigMap" and .data["config.yaml"] != null) | .data["config.yaml"]' <<<"$OUT" | yq "$1"; }
with_values() { # with_values <yq expression> <command...>: run the command on a copy of the chart whose values.yaml is edited
  local expr=$1 dir rc saved=$CHART; shift
  dir=$(mktemp -d)
  cp -R "$CHART" "$dir/apisix" && yq -i "$expr" "$dir/apisix/values.yaml" || { rm -rf "$dir"; return 1; }
  CHART="$dir/apisix"; "$@"; rc=$?; CHART=$saved
  rm -rf "$dir"
  return $rc
}
secret_exists() { [ -n "$(yq "select(.kind == \"Secret\" and .metadata.name == \"$1\") | .metadata.name" <<<"$OUT")" ]; }
no_secret() { ! secret_exists "$1"; }

# --- the NetworkPolicy and the client label -------------------------------------

check "default: renders" render apisix
check "default: the APISIX pods carry the etcd client label" is "$(pod_label apisix-etcd-client)" true
check "default: etcd accepts only the client label and its own pods" is "$(policy_from apisix-etcd)" \
  '[{"podSelector":{"matchLabels":{"apisix-etcd-client":"true"}}},{"podSelector":{"matchLabels":{"app.kubernetes.io/instance":"apisix","app.kubernetes.io/name":"etcd","app.kubernetes.io/component":"etcd"}}}]'

check "default: no rule admits any pod to the client or peer port" is "$(open_client_rules apisix-etcd)" 0
check "default: the etcd chart's pre-upgrade job carries the label too" is "$(job_label apisix-etcd-pre-upgrade apisix-etcd-client)" true

check "metrics on the client port: fails" fails_with "etcd.metrics.enabled serves the metrics on the etcd client port" \
  apisix --set etcd.metrics.enabled=true
check "metrics on a port of their own: renders" render apisix --set etcd.metrics.enabled=true --set etcd.metrics.useSeparateEndpoint=true
check "metrics on a port of their own: no rule admits any pod to the client or peer port" is "$(open_client_rules apisix-etcd)" 0
check "metrics on the client port with allowExternal: renders" render apisix --set etcd.metrics.enabled=true \
  --set etcd.networkPolicy.allowExternal=true
check "metrics with the NetworkPolicy turned off: renders" render apisix --set etcd.metrics.enabled=true \
  --set etcd.networkPolicy.enabled=false

LONG_RELEASE=apisix-$(printf '%046d' 0 | tr 0 a)   # 53 characters, the longest name Helm allows
check "a long release name: fails, the client label would be too long" fails_with "but a label key has at most 63 characters" \
  "$LONG_RELEASE"
check "a long etcd.fullnameOverride: fails as well" fails_with "but a label key has at most 63 characters" \
  apisix --set etcd.fullnameOverride="etcd-$(printf '%052d' 0 | tr 0 b)"
check "a long etcd.nameOverride: fails, and the message does not suggest one" \
  fails_with "use a shorter release name or etcd.fullnameOverride (APISIX does not find etcd under an etcd.nameOverride)" \
  apisix --set etcd.nameOverride="etcd-$(printf '%052d' 0 | tr 0 c)"
check "a long release name with allowExternal: renders" render "$LONG_RELEASE" --set etcd.networkPolicy.allowExternal=true
check "a long release name with allowExternal: every label key is valid" bash -c '[ "$1" -le 63 ]' _ "$(longest_label)"
EDGE_RELEASE=apisix-$(printf '%044d' 0 | tr 0 a)   # 51 characters: the client label has exactly 63
check "a client label of exactly 63 characters: renders" render "$EDGE_RELEASE"
check "a client label of exactly 63 characters: the APISIX pods carry it" \
  is "$(pod_label "$EDGE_RELEASE-etcd-client")" true
check "a client label of exactly 63 characters: and the policy uses it" is \
  "$(policy_from "$EDGE_RELEASE-etcd" | yq -p json '.[0].podSelector.matchLabels | keys | join(",")')" "$EDGE_RELEASE-etcd-client"

# helm upgrade --reuse-values renders with the default values of the chart version
# it upgrades from. Those of chart 2.x set no etcd.networkPolicy, so the etcd chart's
# allowExternal: true applies, and give the pre-upgrade job no client label.
OLD_VALUES_ERROR="etcd.preUpgradeJob.podLabels lacks the client label"
check "values of chart 2.x, as --reuse-values renders them: fails" with_values \
  'del(.etcd.networkPolicy) | del(.etcd.preUpgradeJob)' fails_with "$OLD_VALUES_ERROR" apisix
check "values of chart 2.x with labels of their own on the pre-upgrade job: fails too" with_values \
  'del(.etcd.networkPolicy) | .etcd.preUpgradeJob.podLabels = {"team": "gateway"}' fails_with "$OLD_VALUES_ERROR" apisix
check "pre-upgrade job without labels: fails" fails_with "$OLD_VALUES_ERROR" apisix --set etcd.preUpgradeJob.podLabels=null
check "pre-upgrade job without labels, NetworkPolicy turned off: renders" render apisix \
  --set etcd.preUpgradeJob.podLabels=null --set etcd.networkPolicy.enabled=false
check "pre-upgrade job with labels of its own: renders" render apisix --set etcd.preUpgradeJob.podLabels.team=gateway
check "pre-upgrade job with labels of its own: the client label is kept" \
  is "$(job_label apisix-etcd-pre-upgrade apisix-etcd-client)" true

check "etcd jobs: renders" render apisix --set etcd.disasterRecovery.enabled=true \
  --set etcd.disasterRecovery.pvc.existingClaim=snapshots --set etcd.defrag.enabled=true
check "etcd jobs: the snapshot job carries the label" is "$(job_label apisix-etcd-snapshotter apisix-etcd-client)" true
check "etcd jobs: the defragmentation job carries the label" is "$(job_label apisix-etcd-defrag apisix-etcd-client)" true

check "allowExternal: renders" render apisix --set etcd.networkPolicy.allowExternal=true
check "allowExternal: the client port accepts any pod" is "$(policy_from apisix-etcd)" null
check "allowExternal: the label is still set" is "$(pod_label apisix-etcd-client)" true

check "nameOverride: renders" render apisix --set etcd.nameOverride=kv
check "nameOverride: the label follows the etcd name" is "$(pod_label apisix-kv-client)" true
check "nameOverride: and so does the policy" is "$(policy_from apisix-kv | yq -p json '.[0].podSelector.matchLabels | keys | join(",")')" apisix-kv-client

check "fullnameOverride: renders" render apisix --set etcd.fullnameOverride=kv
check "fullnameOverride: the label follows the etcd name" is "$(pod_label kv-client)" true
check "fullnameOverride: and so does the policy" is "$(policy_from kv | yq -p json '.[0].podSelector.matchLabels | keys | join(",")')" kv-client
check "fullnameOverride: and the pre-upgrade job's label" is "$(job_label kv-pre-upgrade kv-client)" true

check "release name with etcd in it: renders" render my-etcd
check "release name with etcd in it: the label uses the etcd chart's name" is "$(pod_label my-etcd-client)" true

check "external etcd: renders" render apisix --set etcd.enabled=false --set 'externalEtcd.host[0]=http://etcd.example:2379'
check "external etcd: no client label" is "$(pod_labels)" "app.kubernetes.io/name,app.kubernetes.io/instance"

check "client label also in podLabels: renders" render apisix --set podLabels.apisix-etcd-client=true \
  --set podLabels.team=gateway
check "client label also in podLabels: it appears once" is \
  "$(yq 'select(.kind == "Deployment") | .spec.template.metadata.labels' <<<"$OUT" | grep -c '^apisix-etcd-client:')" 1
check "client label also in podLabels: its value is the string the policy expects" \
  is "$(pod_label_type apisix-etcd-client)" '!!str'
check "client label also in podLabels: the other labels are kept" is "$(pod_label team)" gateway
check "client label set to false in podLabels: renders" render apisix --set-string podLabels.apisix-etcd-client=false
check "client label set to false in podLabels: the chart's value stays" is "$(pod_label apisix-etcd-client)" true

check "hostNetwork: fails, the policy cannot select pods in the host network" \
  fails_with "hostNetwork: true: most network plugins cannot select pods in the host network" apisix --set hostNetwork=true
check "hostNetwork with allowExternal: renders" render apisix --set hostNetwork=true --set etcd.networkPolicy.allowExternal=true
check "hostNetwork with an ipBlock rule: renders" render apisix --set hostNetwork=true \
  --set-json 'etcd.networkPolicy.extraIngress=[{"ports":[{"port":2379}],"from":[{"ipBlock":{"cidr":"10.0.0.0/8"}}]}]'
check "hostNetwork with only a podSelector rule, as for the dashboard: fails" \
  fails_with "hostNetwork: true: most network plugins cannot select pods in the host network" apisix --set hostNetwork=true \
  --set-json 'etcd.networkPolicy.extraIngress=[{"ports":[{"port":2379}],"from":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"apisix-dashboard"}}}]}]'
check "hostNetwork with the dashboard rule and an ipBlock rule: renders" render apisix --set hostNetwork=true \
  --set-json 'etcd.networkPolicy.extraIngress=[{"ports":[{"port":2379}],"from":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"apisix-dashboard"}}}]},{"ports":[{"port":2379}],"from":[{"ipBlock":{"cidr":"10.0.1.17/32"}}]}]'
check "hostNetwork with a rule for every source: renders" render apisix --set hostNetwork=true \
  --set-json 'etcd.networkPolicy.extraIngress=[{"ports":[{"port":2379}]}]'
check "hostNetwork with rules written as a templated string: fails, the chart cannot check them" \
  fails_with "hostNetwork: true: most network plugins cannot select pods in the host network" apisix --set hostNetwork=true \
  --set-string 'etcd.networkPolicy.extraIngress=- from: [{podSelector: {}}]'
check "hostNetwork with external etcd: renders" render apisix --set hostNetwork=true --set etcd.enabled=false \
  --set 'externalEtcd.host[0]=http://etcd.example:2379'

check "DaemonSet: renders" render apisix --set useDaemonSet=true
check "DaemonSet: the pods carry the etcd client label" is "$(pod_label apisix-etcd-client)" true

# --- the root password ---------------------------------------------------------------

check "default again: renders" render apisix
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
