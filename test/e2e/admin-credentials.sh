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
# End-to-end tests for the Admin API keys of the apisix chart, against a real
# cluster (for example kind) with real APISIX and ingress controller pods.
# Needs kubectl, helm and curl, and network access to apache.github.io for the
# upgrade test. Run from the repository root after `helm dependency build charts/apisix`.
#
#   OLD_CHART_VERSION  chart version to upgrade from (default 2.18.2)
#   KEEP_NAMESPACES=1  keep the test namespaces for debugging

set -uo pipefail

HELM=${HELM:-helm}
CHART=${CHART:-charts/apisix}
OLD_CHART_VERSION=${OLD_CHART_VERSION:-2.18.2}
PUBLIC_ADMIN=edd1c9f034335f136f87ad84b625c8f1
GUIDE=(--set apisix.deployment.role=traditional
       --set apisix.deployment.role_traditional.config_provider=yaml
       --set etcd.enabled=false
       --set ingress-controller.enabled=true
       --set ingress-controller.config.provider.type=apisix-standalone)

passed=0
failed=0
PF_PIDS=()
NAMESPACES=()

cleanup() {
  for pid in "${PF_PIDS[@]:-}"; do [ -n "$pid" ] && { kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; }; done
  if [ "${KEEP_NAMESPACES:-}" != 1 ]; then
    for ns in "${NAMESPACES[@]:-}"; do
      [ -n "$ns" ] || continue
      $HELM uninstall --namespace "$ns" apisix --wait >/dev/null 2>&1
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

wait_for() { # wait_for <seconds> <command...>: retry until the command succeeds
  local deadline=$((SECONDS + $1)); shift
  until "$@" >/dev/null 2>&1; do
    [ "$SECONDS" -ge "$deadline" ] && return 1
    sleep 2
  done
}

port_forward() { # port_forward <namespace> <service> <local port> <service port>
  kubectl --namespace "$1" port-forward "svc/$2" "$3:$4" >/dev/null 2>&1 &
  PF_PIDS+=($!)
  wait_for 60 curl -s -o /dev/null "http://127.0.0.1:$3/"
}

stop_port_forwards() {
  for pid in "${PF_PIDS[@]:-}"; do [ -n "$pid" ] && { kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; }; done
  PF_PIDS=()
}

http_code() { # http_code <url> [curl args...]
  local url=$1; shift
  curl -s -o /dev/null -w '%{http_code}' "$@" "$url"
}

admin_code() { # admin_code <admin port> <path> <key>
  http_code "http://127.0.0.1:$1$2" -H "X-API-KEY: $3"
}

is() { [ "$1" = "$2" ] || { echo "       expected '$2', got '$1'" >&2; return 1; }; }

route_ok() { # route_ok <gateway port> <host>
  [ "$(http_code "http://127.0.0.1:$1/" -H "Host: $2")" = 200 ]
}

secret_key() { # secret_key <namespace> <secret> <field>
  kubectl --namespace "$1" get secret "$2" -o "jsonpath={.data.$3}" | base64 -d
}

deploy_backend() { # deploy_backend <namespace> <host>
  kubectl --namespace "$1" create deployment echo --image=nginx:1.27-alpine >/dev/null
  kubectl --namespace "$1" expose deployment echo --port=80 >/dev/null
  kubectl --namespace "$1" apply -f - >/dev/null <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
spec:
  ingressClassName: apisix
  rules:
    - host: $2
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: echo
                port:
                  number: 80
EOF
  kubectl --namespace "$1" rollout status deployment/echo --timeout=180s >/dev/null
}

uninstall_namespace() { # cluster-scoped controller resources (IngressClass, ClusterRole) must go before the next install
  $HELM uninstall --namespace "$1" apisix --wait >/dev/null 2>&1
  kubectl delete namespace "$1" --wait=true --timeout=180s >/dev/null 2>&1
}

new_namespace() {
  kubectl create namespace "$1" >/dev/null
  NAMESPACES+=("$1")
}

echo "# install with the getting-started guide's values (no key configured)"
NS=admin-e2e-guide
new_namespace $NS
$HELM install apisix $CHART --namespace $NS "${GUIDE[@]}" --wait --timeout 5m >/dev/null
check "$HELM install succeeds" is $? 0
KEY=$(secret_key $NS apisix-admin-credentials admin)
check "a 32-character admin key was generated" eval '[[ "$KEY" =~ ^[A-Za-z0-9]{32}$ ]]'
port_forward $NS apisix-admin 19180 9180
port_forward $NS apisix-gateway 19080 80
check "Admin API accepts the generated key" is "$(admin_code 19180 /apisix/admin/configs "$KEY")" 200
check "Admin API rejects the public default key" is "$(admin_code 19180 /apisix/admin/configs $PUBLIC_ADMIN)" 401
check "Admin API rejects a request without a key" is "$(http_code http://127.0.0.1:19180/apisix/admin/configs)" 401
deploy_backend $NS echo.test
check "an Ingress route works, so the controller uses the generated key" wait_for 180 route_ok 19080 echo.test
$HELM upgrade apisix $CHART --namespace $NS "${GUIDE[@]}" --dry-run=client >/dev/null 2>&1
check "a client-side dry-run upgrade (no cluster access) does not trip the upgrade check" is $? 0

echo "# $HELM upgrade keeps the key"
$HELM upgrade apisix $CHART --namespace $NS "${GUIDE[@]}" --set podAnnotations.e2e=upgrade --wait --timeout 5m >/dev/null
check "$HELM upgrade succeeds" is $? 0
check "the generated key is unchanged" is "$(secret_key $NS apisix-admin-credentials admin)" "$KEY"
stop_port_forwards
port_forward $NS apisix-admin 19180 9180
port_forward $NS apisix-gateway 19080 80
check "Admin API still accepts the key after the upgrade" is "$(admin_code 19180 /apisix/admin/configs "$KEY")" 200
check "the Ingress route still works" wait_for 180 route_ok 19080 echo.test

echo "# rotate the generated key"
NEW_KEY=RotatedAdminKey$(date +%s)Abc
kubectl --namespace $NS patch secret apisix-admin-credentials -p "{\"data\":{\"admin\":\"$(printf %s "$NEW_KEY" | base64)\"}}" >/dev/null
kubectl --namespace $NS rollout restart deployment/apisix >/dev/null
kubectl --namespace $NS rollout status deployment/apisix --timeout=300s >/dev/null
stop_port_forwards
port_forward $NS apisix-admin 19180 9180
port_forward $NS apisix-gateway 19080 80
check "Admin API accepts the new key" is "$(admin_code 19180 /apisix/admin/configs "$NEW_KEY")" 200
check "Admin API rejects the old key" is "$(admin_code 19180 /apisix/admin/configs "$KEY")" 401
kubectl --namespace $NS patch ingress echo --type=json -p '[{"op":"replace","path":"/spec/rules/0/host","value":"echo2.test"}]' >/dev/null
check "a changed Ingress reaches APISIX, so the controller picked up the new key" wait_for 180 route_ok 19080 echo2.test
$HELM upgrade apisix $CHART --namespace $NS "${GUIDE[@]}" --set podAnnotations.e2e=after-rotation --wait --timeout 5m >/dev/null
check "an upgrade after the rotation succeeds" is $? 0
check "a later upgrade keeps the rotated key" is "$(secret_key $NS apisix-admin-credentials admin)" "$NEW_KEY"
stop_port_forwards
port_forward $NS apisix-admin 19180 9180
check "restarted APISIX accepts the rotated key" is "$(admin_code 19180 /apisix/admin/configs "$NEW_KEY")" 200
stop_port_forwards

echo "# upgrades refuse a damaged generated Secret"
kubectl --namespace $NS patch secret apisix-admin-credentials --type=json -p '[{"op":"remove","path":"/data/viewer"}]' >/dev/null
OUT=$($HELM upgrade apisix $CHART --namespace $NS "${GUIDE[@]}" --wait --timeout 5m 2>&1)
rc=$?
check "an upgrade fails when the viewer key was deleted from the Secret" test "$rc" -ne 0
check "the error names the missing viewer key" grep -q "does not contain the viewer key" <<<"$OUT"
kubectl --namespace $NS patch secret apisix-admin-credentials -p "{\"data\":{\"viewer\":\"$(printf %s ViewerAgain456 | base64)\",\"admin\":\"$(printf %s $PUBLIC_ADMIN | base64)\"}}" >/dev/null
OUT=$($HELM upgrade apisix $CHART --namespace $NS "${GUIDE[@]}" --wait --timeout 5m 2>&1)
rc=$?
check "an upgrade fails when the Secret holds the public default key" test "$rc" -ne 0
check "the error says the key is publicly known" grep -q "is a publicly known default key" <<<"$OUT"
uninstall_namespace $NS

echo "# existing Secret (apisix.admin.credentials.secretName)"
NS=admin-e2e-secret
new_namespace $NS
kubectl --namespace $NS create secret generic my-admin --from-literal=admin=$PUBLIC_ADMIN --from-literal=viewer=SecretViewerKey456 >/dev/null
OUT=$($HELM install apisix $CHART --namespace $NS "${GUIDE[@]}" --set apisix.admin.credentials.secretName=my-admin --wait --timeout 5m 2>&1)
rc=$?
check "install fails when the Secret holds the public default key" test "$rc" -ne 0
check "the error names the Secret" grep -q "in the Secret my-admin" <<<"$OUT"
kubectl --namespace $NS create secret generic my-admin --from-literal=admin=SecretAdminKey123 --from-literal=viewer=SecretViewerKey456 \
  --dry-run=client -o yaml | kubectl replace -f - >/dev/null
$HELM install apisix $CHART --namespace $NS "${GUIDE[@]}" --set apisix.admin.credentials.secretName=my-admin --wait --timeout 5m >/dev/null
check "install with another key in the Secret succeeds" is $? 0
port_forward $NS apisix-admin 19183 9180
port_forward $NS apisix-gateway 19083 80
check "Admin API accepts the key from the Secret" is "$(admin_code 19183 /apisix/admin/configs SecretAdminKey123)" 200
deploy_backend $NS secret.test
check "an Ingress route works, so the controller reads the same Secret" wait_for 180 route_ok 19083 secret.test
stop_port_forwards
uninstall_namespace $NS

echo "# upgrade a release that used the public default keys"
NS=admin-e2e-upgrade
new_namespace $NS
$HELM repo add apisix https://apache.github.io/apisix-helm-chart >/dev/null 2>&1
$HELM repo update apisix >/dev/null
$HELM install apisix apisix/apisix --version "$OLD_CHART_VERSION" --namespace $NS "${GUIDE[@]}" \
  --set ingress-controller.gatewayProxy.createDefault=true --wait --timeout 5m >/dev/null
check "chart $OLD_CHART_VERSION installs" is $? 0
OUT=$($HELM upgrade apisix $CHART --namespace $NS "${GUIDE[@]}" --wait --timeout 5m 2>&1)
rc=$?
check "upgrading without new keys fails" test "$rc" -ne 0
check "the error explains what to do" grep -q "ADMIN KEY ERROR" <<<"$OUT"
check "the release was not changed" is "$($HELM history apisix --namespace $NS --max 1 -o json | grep -o '"revision":[0-9]*')" '"revision":1'
port_forward $NS apisix-admin 19181 9180
check "the old key still works after the failed upgrade" is "$(admin_code 19181 /apisix/admin/configs $PUBLIC_ADMIN)" 200
stop_port_forwards
$HELM upgrade apisix $CHART --namespace $NS "${GUIDE[@]}" \
  --set apisix.admin.credentials.admin=UpgradedAdminKey123 --set apisix.admin.credentials.viewer=UpgradedViewerKey456 \
  --wait --timeout 5m >/dev/null
check "upgrading with new keys succeeds" is $? 0
port_forward $NS apisix-admin 19181 9180
port_forward $NS apisix-gateway 19081 80
check "Admin API accepts the new key" is "$(admin_code 19181 /apisix/admin/configs UpgradedAdminKey123)" 200
check "Admin API rejects the public default key" is "$(admin_code 19181 /apisix/admin/configs $PUBLIC_ADMIN)" 401
deploy_backend $NS upgraded.test
check "an Ingress route works after the upgrade" wait_for 180 route_ok 19081 upgraded.test
stop_port_forwards
uninstall_namespace $NS

echo "# upgrade a $OLD_CHART_VERSION release that used its own keys"
NS=admin-e2e-explicit
new_namespace $NS
OWN=(--set apisix.admin.credentials.admin=OwnAdminKey123 --set apisix.admin.credentials.viewer=OwnViewerKey456
     --set ingress-controller.gatewayProxy.createDefault=true
     --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value=OwnAdminKey123)
$HELM install apisix apisix/apisix --version "$OLD_CHART_VERSION" --namespace $NS "${GUIDE[@]}" "${OWN[@]}" --wait --timeout 5m >/dev/null
check "chart $OLD_CHART_VERSION installs with its own keys" is $? 0
$HELM upgrade apisix $CHART --namespace $NS "${GUIDE[@]}" "${OWN[@]}" --wait --timeout 5m >/dev/null
check "upgrading with the same values succeeds" is $? 0
port_forward $NS apisix-admin 19184 9180
port_forward $NS apisix-gateway 19084 80
check "the existing key still works" is "$(admin_code 19184 /apisix/admin/configs OwnAdminKey123)" 200
deploy_backend $NS explicit.test
check "an Ingress route works through the createDefault GatewayProxy" wait_for 180 route_ok 19084 explicit.test
stop_port_forwards
uninstall_namespace $NS

echo "# default values (bundled etcd)"
NS=admin-e2e-etcd
new_namespace $NS
$HELM install apisix $CHART --namespace $NS --wait --timeout 8m >/dev/null
check "$HELM install succeeds" is $? 0
KEY=$(secret_key $NS apisix-admin-credentials admin)
port_forward $NS apisix-admin 19182 9180
check "Admin API accepts the generated key" is "$(admin_code 19182 /apisix/admin/routes "$KEY")" 200
check "Admin API rejects the public default key" is "$(admin_code 19182 /apisix/admin/routes $PUBLIC_ADMIN)" 401
stop_port_forwards

echo
echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
