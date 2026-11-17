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
# Render tests for the webhook certificate of the ingress controller chart: the
# default one that the chart generates, the one that cert-manager issues, and
# the values of chart versions that know nothing about cert-manager. Needs helm
# and yq (https://github.com/mikefarah/yq, v4). Run from the repository root.
# Set HELM to use another helm binary.

set -uo pipefail

HELM=${HELM:-helm}
for tool in "${HELM%% *}" yq; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 2; }
done
CHART=charts/apisix-ingress-controller

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

render() { # render [helm args...]; sets OUT and ERR, returns helm's exit code
  local errfile rc
  errfile=$(mktemp)
  OUT=$($HELM template demo "$CHART" --namespace demo "$@" 2>"$errfile")
  rc=$?
  ERR=$(cat "$errfile"); rm -f "$errfile"
  [ $rc -eq 0 ] || echo "       $ERR" >&2
  return $rc
}

is() { [ "$1" = "$2" ] || { echo "       expected '$2', got '$1'" >&2; return 1; }; }
fails_with() { # fails_with <message part> [helm args...]
  local text=$1; shift
  if render "$@" 2>/dev/null; then echo "       rendered without an error" >&2; return 1; fi
  grep -qF -- "$text" <<<"$ERR" || { echo "       error was: $ERR" >&2; return 1; }
}
count_kind() { yq "select(.kind == \"$1\") | .kind" <<<"$OUT" | grep -c .; }
webhook_config() { yq 'select(.kind == "ValidatingWebhookConfiguration")' <<<"$OUT"; }
ca_bundles() { # the distinct, non-empty caBundle values of the webhooks
  webhook_config | yq '[.webhooks[].clientConfig.caBundle | select(. != null and . != "")] | unique | length'
}
with_values() { # with_values <yq expression> <command...>: run the command on a copy of the chart whose values.yaml is edited
  local expr=$1 dir rc saved=$CHART; shift
  dir=$(mktemp -d)
  cp -R "$CHART" "$dir/chart" && yq -i "$expr" "$dir/chart/values.yaml" || { rm -rf "$dir"; return 1; }
  CHART="$dir/chart"; "$@"; rc=$?; CHART=$saved
  rm -rf "$dir"
  return $rc
}
same_twice() { # the output of two renders is identical
  local first
  render "$@" || return 1
  first=$OUT
  render "$@" || return 1
  [ "$first" = "$OUT" ] || { echo "       the two renders differ" >&2; return 1; }
}

# --- the default: the chart generates the certificate ------------------------------

check "default: renders" render
check "default: the chart renders the Secret with the certificate" is "$(count_kind Secret)" 1
check "default: no cert-manager resources" is "$(( $(count_kind Certificate) + $(count_kind Issuer) ))" 0
check "default: no inject-ca-from annotation" is "$(webhook_config | yq '.metadata.annotations["cert-manager.io/inject-ca-from"]')" null
check "default: the webhooks carry the generated CA" is "$(ca_bundles)" 1

# --- cert-manager issues the certificate ----------------------------------------------

CM=(--set webhook.certManager.enabled=true)
check "cert-manager: renders" render "${CM[@]}"
check "cert-manager: two renders are identical" same_twice "${CM[@]}"
check "cert-manager: the chart renders no Secret" is "$(count_kind Secret)" 0
check "cert-manager: no webhook has a caBundle of its own" is "$(ca_bundles)" 0
check "cert-manager: the webhook configuration asks cainjector for the CA of the Certificate" is \
  "$(webhook_config | yq '.metadata.annotations["cert-manager.io/inject-ca-from"]')" \
  "demo/$(yq 'select(.kind == "Certificate") | .metadata.name' <<<"$OUT")"
check "cert-manager: the Certificate writes the Secret that the controller mounts" is \
  "$(yq 'select(.kind == "Certificate") | .spec.secretName' <<<"$OUT")" \
  "$(yq 'select(.kind == "Deployment") | .spec.template.spec.volumes[] | select(.secret) | .secret.secretName' <<<"$OUT" | head -1)"
check "cert-manager: the Certificate covers the webhook Service" is \
  "$(yq 'select(.kind == "Certificate") | .spec.dnsNames | contains(["'"$(yq 'select(.kind == "Service" and .spec.ports[0].name == "webhook") | .metadata.name' <<<"$OUT")"'.demo.svc"])' <<<"$OUT")" true
check "cert-manager: the Certificate has a short subject, so the self-signed Issuer has no empty DN" is \
  "$(yq 'select(.kind == "Certificate") | .spec.commonName' <<<"$OUT")" apisix-ingress-webhook
check "cert-manager: a self-signed Issuer is created" is "$(count_kind Issuer)" 1
check "cert-manager: the Certificate refers to that Issuer" is \
  "$(yq 'select(.kind == "Certificate") | .spec.issuerRef.name' <<<"$OUT")" \
  "$(yq 'select(.kind == "Issuer") | .metadata.name' <<<"$OUT")"

check "cert-manager with an issuerRef: renders" render "${CM[@]}" \
  --set webhook.certManager.issuerRef.name=my-issuer --set webhook.certManager.issuerRef.kind=ClusterIssuer
check "cert-manager with an issuerRef: no Issuer is created" is "$(count_kind Issuer)" 0
check "cert-manager with an issuerRef: the Certificate uses it" is \
  "$(yq 'select(.kind == "Certificate") | .spec.issuerRef | .name + "/" + .kind' <<<"$OUT")" my-issuer/ClusterIssuer
check "cert-manager with a duration: renders" render "${CM[@]}" --set webhook.certManager.duration=720h
check "cert-manager with a duration: the Certificate has it" is "$(yq 'select(.kind == "Certificate") | .spec.duration' <<<"$OUT")" 720h
check "cert-manager with annotations of its own: renders" render "${CM[@]}" --set-string webhook.annotations.team=gateway
check "cert-manager with annotations of its own: both are kept" is \
  "$(webhook_config | yq '.metadata.annotations | keys | join(",")')" "cert-manager.io/inject-ca-from,team"

check "cert-manager together with a provided certificate: fails" fails_with \
  "webhook.certManager.enabled and webhook.certificate.provided cannot both be true" "${CM[@]}" \
  --set webhook.certificate.provided=true --set webhook.certificate.secretName=mine
check "webhook turned off: renders without any of it" render "${CM[@]}" --set webhook.enabled=false
check "webhook turned off: no Certificate" is "$(count_kind Certificate)" 0

# --- the provided certificate keeps working --------------------------------------------

check "provided certificate: renders" render --set webhook.certificate.provided=true \
  --set webhook.certificate.secretName=mine --set webhook.certificate.caBundle=Q0E=
check "provided certificate: the webhooks carry the given caBundle" is "$(ca_bundles)" 1
check "provided certificate: no Secret and no cert-manager resources" is \
  "$(( $(count_kind Secret) + $(count_kind Certificate) + $(count_kind Issuer) ))" 0

# --- helm upgrade --reuse-values renders with the values of the chart version it upgrades from,
# --- which have no webhook.certManager

NO_CM='del(.webhook.certManager)'
generated_secret() { render && [ "$(count_kind Secret)" -eq 1 ] && [ "$(ca_bundles)" -eq 1 ]; }
check "values without webhook.certManager: render as before" with_values "$NO_CM" render
check "values without webhook.certManager: the chart still generates the certificate" with_values "$NO_CM" generated_secret
check "values without webhook.certManager: a provided certificate still works" with_values "$NO_CM" render   --set webhook.certificate.provided=true --set webhook.certificate.secretName=mine --set webhook.certificate.caBundle=Q0E=

echo
echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
