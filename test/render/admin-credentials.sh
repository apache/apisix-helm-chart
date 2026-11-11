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
# Render tests for the Admin API credentials of the apisix chart.
# Needs helm and yq (https://github.com/mikefarah/yq, v4). Run from the
# repository root after `helm dependency build charts/apisix`.
# Set HELM to use another helm binary, e.g. HELM="docker run ... helm".

set -uo pipefail

HELM=${HELM:-helm}
for tool in "${HELM%% *}" yq base64; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 2; }
done
CHART=charts/apisix
PUBLIC_ADMIN=edd1c9f034335f136f87ad84b625c8f1
PUBLIC_VIEWER=4054f7cf07e344346cd3f287985e76a2
GUIDE=(--set apisix.deployment.role=traditional
       --set apisix.deployment.role_traditional.config_provider=yaml
       --set etcd.enabled=false
       --set ingress-controller.enabled=true
       --set ingress-controller.config.provider.type=apisix-standalone)

passed=0
failed=0
OUT=""

check() { # check <description> <command...>
  local desc=$1; shift
  if "$@"; then
    echo "ok   - $desc"; passed=$((passed + 1))
  else
    echo "FAIL - $desc"; failed=$((failed + 1))
  fi
}

render() { # render <release> [helm args...]; sets OUT and returns helm's exit code
  local release=$1; shift
  OUT=$($HELM template "$release" "$CHART" --namespace demo "$@" 2>&1)
}

q() { yq "$1" <<<"$OUT"; }
config() { q 'select(.kind == "ConfigMap" and .data["config.yaml"] != null) | .data["config.yaml"]' | yq "$1"; }
key_of() { config ".deployment.admin.admin_key[] | select(.name == \"$1\") | .key"; }
env_ref() { # env_ref <env name>  ->  "<secret>/<key>"
  q "select(.kind == \"Deployment\") | .spec.template.spec.containers[] | select(.name == \"apisix\") | .env[] | select(.name == \"$1\") | .valueFrom.secretKeyRef | .name + \"/\" + .key"
}
secret_value() { # secret_value <secret name> <key>  ->  decoded value
  q "select(.kind == \"Secret\" and .metadata.name == \"$1\") | .data.$2" | base64 -d 2>/dev/null
}
count() { q "select(.kind == \"$1\") | .kind" | grep -c "^$1$"; }
no_generated_secret() { [ -z "$(q "select(.kind == \"Secret\" and .metadata.name == \"${1:-apisix}-admin-credentials\") | .kind")" ]; }
has_no_public_key() { # neither in plain text nor base64-encoded in a Secret
  grep -q -e "$PUBLIC_ADMIN" -e "$PUBLIC_VIEWER" <<<"$OUT" && return 1
  local values encoded decoded
  values=$(printf '%s\n' "$OUT" | yq 'select(.kind == "Secret") | .data[]') || return 1
  while IFS= read -r encoded; do
    [ -n "$encoded" ] || continue
    decoded=$(printf '%s' "$encoded" | base64 -d 2>/dev/null)
    [ "$decoded" != "$PUBLIC_ADMIN" ] && [ "$decoded" != "$PUBLIC_VIEWER" ] || return 1
  done <<<"$values"
  return 0
}
eq() { [ "$1" = "$2" ] || { echo "       expected '$2', got '$1'" >&2; return 1; }; }
failed_with() { [ "$1" -ne 0 ] && grep -q "$2" <<<"$OUT"; }

echo "# default values: keys are generated into a Secret"
render apisix; check "renders" eq $? 0
admin=$(secret_value apisix-admin-credentials admin)
viewer=$(secret_value apisix-admin-credentials viewer)
check "generated admin key is 32 alphanumerics" grep -Eq '^[A-Za-z0-9]{32}$' <<<"$admin"
check "generated viewer key is 32 alphanumerics" grep -Eq '^[A-Za-z0-9]{32}$' <<<"$viewer"
check "admin and viewer keys differ" test "$admin" != "$viewer"
check "no publicly known key anywhere in the output" has_no_public_key
check "config reads the admin key from the environment" eq "$(key_of admin)" '${{APISIX_ADMIN_KEY}}'
check "config reads the viewer key from the environment" eq "$(key_of viewer)" '${{APISIX_VIEWER_KEY}}'
check "APISIX_ADMIN_KEY comes from the generated Secret" eq "$(env_ref APISIX_ADMIN_KEY)" "apisix-admin-credentials/admin"
check "APISIX_VIEWER_KEY comes from the generated Secret" eq "$(env_ref APISIX_VIEWER_KEY)" "apisix-admin-credentials/viewer"
render apisix
check "an offline render generates a new key (lookup has no cluster)" test "$(secret_value apisix-admin-credentials admin)" != "$admin"

echo "# Secret name follows the release fullname"
render t
check "release t uses the Secret t-apisix-admin-credentials" eq "$(env_ref APISIX_ADMIN_KEY)" "t-apisix-admin-credentials/admin"

echo "# admin set inline, viewer generated"
render apisix --set apisix.admin.credentials.admin=MyAdminKey123; check "renders" eq $? 0
check "inline admin key is used as is" eq "$(key_of admin)" "MyAdminKey123"
check "viewer key still comes from the generated Secret" eq "$(env_ref APISIX_VIEWER_KEY)" "apisix-admin-credentials/viewer"
check "no APISIX_ADMIN_KEY variable" eq "$(env_ref APISIX_ADMIN_KEY)" ""
check "generated Secret holds only the viewer key" eq "$(q 'select(.kind == "Secret" and .metadata.name == "apisix-admin-credentials") | .data | keys | join(",")')" "viewer"

echo "# both keys set inline: same as before 3.0.0"
render apisix --set apisix.admin.credentials.admin=MyAdminKey123 --set apisix.admin.credentials.viewer=MyViewerKey456
check "renders" eq $? 0
check "admin key rendered inline" eq "$(key_of admin)" "MyAdminKey123"
check "viewer key rendered inline" eq "$(key_of viewer)" "MyViewerKey456"
check "no generated Secret" no_generated_secret
check "no admin key environment variables" eq "$(env_ref APISIX_ADMIN_KEY)$(env_ref APISIX_VIEWER_KEY)" ""

echo "# existing Secret: same as before 3.0.0"
render apisix --set apisix.admin.credentials.secretName=my-admin --set apisix.admin.credentials.secretAdminKey=token
check "renders" eq $? 0
check "APISIX_ADMIN_KEY comes from the existing Secret" eq "$(env_ref APISIX_ADMIN_KEY)" "my-admin/token"
check "APISIX_VIEWER_KEY comes from the existing Secret" eq "$(env_ref APISIX_VIEWER_KEY)" "my-admin/viewer"
check "no generated Secret" no_generated_secret

echo "# publicly known keys are rejected"
render apisix --set apisix.admin.credentials.admin=$PUBLIC_ADMIN
check "public admin key as admin fails" failed_with $? "apisix.admin.credentials.admin is a publicly known default key"
render apisix --set apisix.admin.credentials.viewer=$PUBLIC_VIEWER
check "public viewer key as viewer fails" failed_with $? "apisix.admin.credentials.viewer is a publicly known default key"
render apisix --set apisix.admin.credentials.viewer=$PUBLIC_ADMIN
check "public admin key as viewer fails" failed_with $? "apisix.admin.credentials.viewer is a publicly known default key"

render apisix --set-string "apisix.admin.credentials.admin=\"$PUBLIC_ADMIN\"" --set-string "apisix.admin.credentials.viewer=$PUBLIC_VIEWER "
check "a public key wrapped in quotes or spaces does not become the public key" test "$(key_of admin)" != "$PUBLIC_ADMIN" -a "$(key_of viewer)" != "$PUBLIC_VIEWER"

echo "# upgrades never replace a generated key"
render apisix --is-upgrade
check "an upgrade render without cluster access (helm diff, --dry-run=client) does not fail" eq $? 0
render apisix --is-upgrade --set apisix.admin.credentials.admin=MyAdminKey123 --set apisix.admin.credentials.viewer=MyViewerKey456
check "upgrade with both keys set inline renders" eq $? 0
render apisix --is-upgrade --set apisix.admin.credentials.secretName=my-admin
check "upgrade with an existing Secret renders" eq $? 0
render apisix --is-upgrade --set apisix.admin.enabled=false
check "upgrade with the Admin API disabled renders (no client can be cut off)" eq $? 0

echo "# bundled ingress controller (the getting-started guide's values)"
render apisix "${GUIDE[@]}"; check "renders" eq $? 0
check "exactly one GatewayProxy" eq "$(count GatewayProxy)" 1
check "GatewayProxy is named apisix-config" eq "$(q 'select(.kind == "GatewayProxy") | .metadata.name')" "apisix-config"
check "GatewayProxy targets the Admin API Service" eq "$(q 'select(.kind == "GatewayProxy") | .spec.provider.controlPlane.service | .name + ":" + (.port | tostring)')" "apisix-admin:9180"
check "GatewayProxy reads the generated admin key" eq "$(q 'select(.kind == "GatewayProxy") | .spec.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef | .name + "/" + .key')" "apisix-admin-credentials/admin"
check "IngressClass references that GatewayProxy" eq "$(q 'select(.kind == "IngressClass") | .spec.parameters.name')" "apisix-config"
check "no publicly known key anywhere in the output" has_no_public_key

render t "${GUIDE[@]}"
check "release t: GatewayProxy t-config targets t-apisix-admin" eq "$(q 'select(.kind == "GatewayProxy") | .metadata.name + " " + .spec.provider.controlPlane.service.name')" "t-config t-apisix-admin"
check "release t: IngressClass references t-config" eq "$(q 'select(.kind == "IngressClass") | .spec.parameters.name')" "t-config"

render apisix "${GUIDE[@]}" --set apisix.admin.credentials.admin=MyAdminKey123
check "inline admin key is passed to the GatewayProxy as a value" eq "$(q 'select(.kind == "GatewayProxy") | .spec.provider.controlPlane.auth.adminKey.value')" "MyAdminKey123"

render apisix "${GUIDE[@]}" --set apisix.admin.credentials.secretName=my-admin --set apisix.admin.credentials.secretAdminKey=token
check "existing Secret is passed to the GatewayProxy" eq "$(q 'select(.kind == "GatewayProxy") | .spec.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef | .name + "/" + .key')" "my-admin/token"

render apisix "${GUIDE[@]}" --set 'ingress-controller.gatewayProxy.plugins[0].name=cors' --set 'ingress-controller.gatewayProxy.plugins[0].enabled=true'
check "gatewayProxy.plugins are passed through" eq "$(q 'select(.kind == "GatewayProxy") | .spec.plugins[0].name')" "cors"
render apisix "${GUIDE[@]}" --set apisix.admin.servicePort=19180 \
  --set ingress-controller.gatewayProxy.provider.controlPlane.tlsVerify=true \
  --set ingress-controller.gatewayProxy.publishService=demo/apisix-gateway \
  --set 'ingress-controller.gatewayProxy.statusAddress[0]=10.0.0.1' \
  --set ingress-controller.gatewayProxy.pluginMetadata.prometheus.disable=false
check "GatewayProxy uses the admin Service port and passes the optional fields through" eq "$(q 'select(.kind == "GatewayProxy") | (.spec.provider.controlPlane.service.port | tostring) + "," + (.spec.provider.controlPlane.tlsVerify | tostring) + "," + .spec.publishService + "," + .spec.statusAddress[0] + "," + (.spec.pluginMetadata.prometheus.disable | tostring)')" "19180,true,demo/apisix-gateway,10.0.0.1,false"

echo "# createDefault: the controller chart creates its own GatewayProxy"
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true
check "fails without a key for it (the guide's old command)" failed_with $? "INGRESS CONTROLLER ERROR: ingress-controller.gatewayProxy.createDefault is true, but no admin key"
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value=$PUBLIC_ADMIN
check "fails with the public default key" failed_with $? "adminKey.value is a publicly known default key"
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value=OtherKey123
check "fails when its key differs from the generated key" failed_with $? "would not use the Admin API key of this release"
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set apisix.admin.credentials.admin=MyAdminKey123 --set apisix.admin.credentials.viewer=MyViewerKey456 \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value=MyAdminKey123
check "renders when its key matches the inline key" eq $? 0
check "only the controller chart's GatewayProxy is rendered" eq "$(count GatewayProxy)" 1
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set apisix.admin.credentials.admin=MyAdminKey123 --set apisix.admin.credentials.viewer=MyViewerKey456 \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.name=wrong-secret \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.key=key
check "fails when it reads another Secret than the inline key" failed_with $? "would not use the Admin API key of this release"
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.name=apisix-admin-credentials \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.key=admin
check "renders when it reads the generated Secret" eq $? 0
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true --set apisix.admin.credentials.secretName=my-admin \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.name=my-admin \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.key=admin
check "renders when it reads the same existing Secret" eq $? 0
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set 'ingress-controller.gatewayProxy.provider.controlPlane.endpoints[0]=http://other-apisix-admin:9180'
check "fails for other endpoints without a key (no public default fallback)" failed_with $? "no admin key is set"
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set 'ingress-controller.gatewayProxy.provider.controlPlane.endpoints[0]=http://other-apisix-admin:9180' \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value=OtherKey123
check "renders for other endpoints with their own key" eq $? 0
check "no publicly known key anywhere in the output" has_no_public_key

render t "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set apisix.admin.credentials.admin=MyAdminKey123 --set apisix.admin.credentials.viewer=MyViewerKey456 \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value=MyAdminKey123
check "fails when it would fall back to the Service apisix-admin in release t" failed_with $? "would use the Service apisix-admin (ingress-controller.apisix.adminService.name), but the Admin API Service of this release is t-apisix-admin"
render t "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set apisix.admin.credentials.admin=MyAdminKey123 --set apisix.admin.credentials.viewer=MyViewerKey456 \
  --set ingress-controller.gatewayProxy.provider.controlPlane.service.name=t-apisix-admin \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value=MyAdminKey123
check "renders in release t with the Service name set and a matching key" eq $? 0
render apisix "${GUIDE[@]}" --set ingress-controller.gatewayProxy.createDefault=true \
  --set ingress-controller.gatewayProxy.provider.controlPlane.service.name=external-admin \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value=ExternalKey123
check "renders for an explicitly named external Service with its own key" eq $? 0
render apisix "${GUIDE[@]}" --set apisix.admin.enabled=false --set ingress-controller.gatewayProxy.createDefault=true \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.name=apisix-admin-credentials \
  --set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.valueFrom.secretKeyRef.key=admin
check "fails when it targets this release but the Admin API is disabled" failed_with $? "but this release has no Admin API"

echo "# the bundled controller in a release without an Admin API"
for extra in "--set apisix.deployment.mode=standalone" "--set apisix.admin.enabled=false" \
             "--set apisix.fullCustomConfig.enabled=true --set apisix.fullCustomConfig.config.apisix.node_listen[0]=9080"; do
  # shellcheck disable=SC2086
  render apisix --set ingress-controller.enabled=true --set etcd.enabled=false $extra
  check "fails instead of referencing a missing GatewayProxy ($extra)" failed_with $? "references the GatewayProxy apisix-config, but this release cannot create it"
done
render apisix --set ingress-controller.enabled=true --set etcd.enabled=false --set apisix.deployment.mode=standalone --set-string ingress-controller.gatewayProxy.name=
check "renders with gatewayProxy.name set to empty" eq $? 0
check "the IngressClass then has no parameters" eq "$(q 'select(.kind == "IngressClass") | .spec.parameters // "none"')" "none"
check "no GatewayProxy" eq "$(count GatewayProxy)" 0

echo "# releases without an Admin API"
render apisix --set apisix.deployment.mode=standalone
check "file-driven standalone renders" eq $? 0
check "no generated Secret" no_generated_secret
check "no admin_key in the config" eq "$(config '.deployment.admin.admin_key | length')" 0
render apisix --set apisix.fullCustomConfig.enabled=true --set 'apisix.fullCustomConfig.config.apisix.node_listen[0]=9080'
check "fullCustomConfig renders" eq $? 0
check "fullCustomConfig: no generated Secret" no_generated_secret
render apisix --set apisix.fullCustomConfig.enabled=true --set "apisix.fullCustomConfig.config.deployment.admin.admin_key[0].key=$PUBLIC_ADMIN"
check "fullCustomConfig with a public default key fails" failed_with $? "apisix.fullCustomConfig.config contains a publicly known default Admin API key"
render apisix --set apisix.fullCustomConfig.enabled=true --set apisix.admin.credentials.admin=$PUBLIC_ADMIN \
  --set-json 'apisix.fullCustomConfig.config.deployment={"admin":{"admin_key":[{"name":"admin","key":"{{ .Values.apisix.admin.credentials.admin }}","role":"admin"}]}}'
check "fullCustomConfig that templates in a public default key fails" failed_with $? "apisix.fullCustomConfig.config contains a publicly known default Admin API key"

echo
echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
