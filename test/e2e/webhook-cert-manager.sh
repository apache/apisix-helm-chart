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
# End-to-end tests for the webhook certificate that cert-manager issues for the
# ingress controller chart: issuance, injection of the CA into the webhook
# configuration, renewal, and the upgrade from a release that generated the
# certificate itself. They install cert-manager into the cluster and do not
# need the controller pods to become ready. Needs kubectl, helm and curl. Run
# from the repository root.
#
#   CERT_MANAGER_VERSION  cert-manager chart version to install (default v1.17.2)
#   OLD_CHART_VERSION     released chart version to upgrade from (default 1.5.0)
#   KEEP_NAMESPACES=1     keep the test namespaces for debugging

set -uo pipefail

HELM=${HELM:-helm}
CHART=${CHART:-charts/apisix-ingress-controller}
CERT_MANAGER_VERSION=${CERT_MANAGER_VERSION:-v1.17.2}
OLD_CHART_VERSION=${OLD_CHART_VERSION:-1.5.0}
NS=webhook-cm-e2e
NS_UPGRADE=webhook-cm-e2e-upgrade
NAMESPACES=("$NS" "$NS_UPGRADE")
# the ValidatingWebhookConfiguration and the IngressClass are cluster-scoped, so the second
# release needs a name and an ingress class of its own
FIRST_RELEASE=ingress
UPGRADE_RELEASE=ingress-upgrade
RELEASE=$FIRST_RELEASE
UPGRADE_CLASS=apisix-upgrade

passed=0
failed=0

cleanup() {
  if [ "${KEEP_NAMESPACES:-}" != 1 ]; then
    for ns in "${NAMESPACES[@]}"; do
      $HELM uninstall --namespace "$ns" "$FIRST_RELEASE" >/dev/null 2>&1
      $HELM uninstall --namespace "$ns" "$UPGRADE_RELEASE" >/dev/null 2>&1
      kubectl delete namespace "$ns" --wait=false >/dev/null 2>&1
    done
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

webhook_name() { kubectl get validatingwebhookconfiguration -l app.kubernetes.io/instance="$RELEASE" -o jsonpath='{.items[0].metadata.name}'; }
# the caBundle of the first webhook, as base64
ca_bundle() { kubectl get validatingwebhookconfiguration "$(webhook_name)" -o jsonpath='{.webhooks[0].clientConfig.caBundle}'; }
secret_name() { kubectl --namespace "$1" get certificate -o jsonpath='{.items[0].spec.secretName}'; }
secret_ca() { # secret_ca <namespace> <secret>: the ca.crt of the Secret, as base64
  kubectl --namespace "$1" get secret "$2" -o jsonpath='{.data.ca\.crt}'
}
certificate_ready() { [ "$(kubectl --namespace "$1" get certificate -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')" = True ]; }
# the caBundle of every webhook equals the given one
all_bundles_are() {
  local bundles
  bundles=$(kubectl get validatingwebhookconfiguration "$(webhook_name)" -o jsonpath='{range .webhooks[*]}{.clientConfig.caBundle}{"\n"}{end}' | sort -u)
  [ "$bundles" = "$1" ]
}
injected() { # injected <namespace>: the CA of the issued Secret is in every webhook
  local ca; ca=$(secret_ca "$1" "$(secret_name "$1")")
  [ -n "$ca" ] && all_bundles_are "$ca"
}
cert_serial() { # the serial number of the certificate in the Secret
  kubectl --namespace "$1" get secret "$(secret_name "$1")" -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial
}

echo "# install cert-manager"
$HELM repo add jetstack https://charts.jetstack.io >/dev/null 2>&1
$HELM repo update jetstack >/dev/null 2>&1
$HELM upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace \
  --version "$CERT_MANAGER_VERSION" --set crds.enabled=true --wait --timeout 5m >/dev/null ||
  { echo "could not install cert-manager" >&2; exit 1; }

echo "# cert-manager issues the certificate and injects its CA"
kubectl create namespace "$NS" >/dev/null
$HELM install "$RELEASE" "$CHART" --namespace "$NS" --set webhook.certManager.enabled=true >/dev/null ||
  { echo "could not install the chart" >&2; exit 1; }
check "the Certificate becomes ready" wait_for 180 certificate_ready "$NS"
check "the CA of the issued Secret is injected into every webhook" wait_for 120 injected "$NS"

echo "# renewal"
BEFORE_SERIAL=$(cert_serial "$NS")
BEFORE_CA=$(ca_bundle)
# deleting the Secret makes cert-manager issue the certificate again, with a new key and CA
kubectl --namespace "$NS" delete secret "$(secret_name "$NS")" >/dev/null
check "a new certificate is issued" wait_for 180 bash -c \
  "[ \"\$(kubectl --namespace $NS get secret $(secret_name "$NS") -o name 2>/dev/null)\" != '' ]"
check "the new certificate has another serial number" wait_for 120 bash -c \
  "s=\$(kubectl --namespace $NS get secret $(secret_name "$NS") -o jsonpath='{.data.tls\\.crt}' | base64 -d | openssl x509 -noout -serial); [ \"\$s\" != '$BEFORE_SERIAL' ]"
check "the new CA is injected into every webhook" wait_for 120 injected "$NS"
check "the injected CA changed" bash -c "[ '$(ca_bundle)' != '$BEFORE_CA' ]"

echo "# a helm upgrade does not change the certificate"
SERIAL=$(cert_serial "$NS")
check "a helm upgrade succeeds" $HELM upgrade "$RELEASE" "$CHART" --namespace "$NS" --set webhook.certManager.enabled=true
check "the upgrade keeps the certificate" is "$(cert_serial "$NS")" "$SERIAL"
check "the upgrade keeps the injected CA" injected "$NS"

echo "# upgrade from a release that generated the certificate itself"
$HELM repo add apisix https://apache.github.io/apisix-helm-chart >/dev/null 2>&1
$HELM repo update apisix >/dev/null 2>&1
kubectl create namespace "$NS_UPGRADE" >/dev/null
RELEASE=$UPGRADE_RELEASE
if $HELM install "$RELEASE" apisix/apisix-ingress-controller --version "$OLD_CHART_VERSION" --namespace "$NS_UPGRADE" \
    --set config.kubernetes.ingressClass="$UPGRADE_CLASS" >/dev/null; then
  OLD_CA=$(ca_bundle)
  check "the old release has a generated CA" bash -c "[ -n '$OLD_CA' ]"
  check "upgrading with --reuse-values renders the chart, which the old values know nothing about" \
    $HELM upgrade "$RELEASE" "$CHART" --namespace "$NS_UPGRADE" --reuse-values
  check "the generated certificate stays after that upgrade" is "$(ca_bundle)" "$OLD_CA"
  check "switching to cert-manager works" $HELM upgrade "$RELEASE" "$CHART" --namespace "$NS_UPGRADE" \
    --reset-then-reuse-values --set webhook.certManager.enabled=true
  check "the Certificate becomes ready" wait_for 180 certificate_ready "$NS_UPGRADE"
  check "cert-manager's CA replaces the generated one in every webhook" wait_for 120 injected "$NS_UPGRADE"
else
  echo "FAIL - could not install chart $OLD_CHART_VERSION"; failed=$((failed + 1))
fi

echo
echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
