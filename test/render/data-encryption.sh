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
# Render tests for apisix.dataEncryption of the apisix chart.
# Needs helm and yq (https://github.com/mikefarah/yq, v4). Run from the
# repository root after `helm dependency build charts/apisix`.
# Set HELM to use another helm binary.

set -uo pipefail

HELM=${HELM:-helm}
for tool in "${HELM%% *}" yq; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 2; }
done
CHART=charts/apisix
NEW=AbCdEfGhIjKlMnOp
BUILTIN_1=qeddd145sfvddff3
BUILTIN_2=edd1c9f0985e76a2
WARNING="WARNING: APISIX encrypts SSL private keys and sensitive plugin fields"
# Full configuration must select a non-empty source, even when only checking env injection.
CUSTOM_CONFIG=(--set apisix.fullCustomConfig.enabled=true
               --set-json 'apisix.fullCustomConfig.config={"apisix":{"node_listen":[9080]}}')

passed=0
failed=0
OUT=""
ERR=""
NOTES=""

check() { # check <description> <command...>
  local desc=$1; shift
  if "$@"; then
    echo "ok   - $desc"; passed=$((passed + 1))
  else
    echo "FAIL - $desc"; failed=$((failed + 1))
  fi
}

render() { # render [helm args...]; sets OUT (manifests) and ERR (stderr), returns helm's exit code
  local errfile rc
  errfile=$(mktemp)
  OUT=$($HELM template apisix "$CHART" --namespace demo "$@" 2>"$errfile")
  rc=$?
  ERR=$(cat "$errfile"); rm -f "$errfile"
  return $rc
}

# NOTES.txt is not part of `helm template` output, and `helm install --dry-run`
# needs a reachable cluster with Helm 3. So render it from a copy of the chart
# in which a ConfigMap template carries the rendered NOTES.txt.
NOTES_CHART=$(mktemp -d) || exit 2
ORIGINAL_NOTES_CHART=$NOTES_CHART
REUSED_CHART=$(mktemp -d) || { rm -rf "$NOTES_CHART"; exit 2; }
trap 'rm -rf "$ORIGINAL_NOTES_CHART" "$REUSED_CHART"' EXIT
cp -R "$CHART"/. "$NOTES_CHART"/
{
  printf '%s\n' 'apiVersion: v1' 'kind: ConfigMap' 'metadata:' '  name: rendered-notes' 'data:' \
    '  notes: {{ include "test.renderedNotes" . | toJson }}' '{{- define "test.renderedNotes" }}'
  cat "$CHART/templates/NOTES.txt"
  printf '\n%s\n' '{{- end }}'
} >"$NOTES_CHART/templates/zz-rendered-notes.yaml"

notes() { # notes [helm args...]; sets NOTES to the rendered NOTES.txt
  NOTES=$($HELM template apisix "$NOTES_CHART" --namespace demo --show-only templates/zz-rendered-notes.yaml "$@" 2>/dev/null |
    yq '.data.notes')
  [ -n "$NOTES" ] && [ "$NOTES" != null ] || { echo "       NOTES could not be rendered" >&2; return 1; }
}

config() { yq 'select(.kind == "ConfigMap" and .data["config.yaml"] != null) | .data["config.yaml"]' <<<"$OUT" | yq "$1"; }
config_text() { yq 'select(.kind == "ConfigMap" and .data["config.yaml"] != null) | .data["config.yaml"]' <<<"$OUT"; }
env_ref() { # env_ref <env name>  ->  "<secret>/<key>"
  yq "select(.kind == \"Deployment\") | .spec.template.spec.containers[] | select(.name == \"apisix\") | .env[] | select(.name == \"$1\") | .valueFrom.secretKeyRef | .name + \"/\" + .key" <<<"$OUT"
}
key_envs() { # names of the keyring environment variables, one per line
  yq 'select(.kind == "Deployment") | .spec.template.spec.containers[] | select(.name == "apisix") | .env[] | select(.name | test("^APISIX_DATA_ENCRYPTION_KEY_")) | .name' <<<"$OUT"
}
is() { [ "$1" = "$2" ] || { echo "       expected '$2', got '$1'" >&2; return 1; }; }
fails_with() { # fails_with <message part> [helm args...]
  local text=$1; shift
  if render "$@"; then echo "       rendered without an error" >&2; return 1; fi
  grep -qF -- "$text" <<<"$ERR" || { echo "       error was: $ERR" >&2; return 1; }
}
warns() { notes "$@" && grep -qF -- "$WARNING" <<<"$NOTES"; }          # warns [helm args...]
does_not_warn() { notes "$@" && ! grep -qF -- "$WARNING" <<<"$NOTES"; } # does_not_warn [helm args...]
notes_say() { local text=$1; shift; notes "$@" && grep -qF -- "$text" <<<"$NOTES"; }

# --- defaults: APISIX's built-in keyring, with a warning ------------------------

check "default: renders" render
check "default: encryption stays enabled" is "$(config '.apisix.data_encryption.enable_encrypt_fields')" true
check "default: no keyring is rendered, APISIX keeps its built-in one" is "$(config '.apisix.data_encryption.keyring')" null
check "default: no keyring environment variable" is "$(key_envs)" ""
check "default: NOTES warns that the built-in keyring is public" warns

# --- upgrading with chart 3.0.0 defaults ----------------------------------------

# --reuse-values replaces the new chart defaults with the previous chart's
# coalesced values. Merely passing an old values file with -f would merge in the
# new defaults and miss this regression. Remove the new map from a chart copy.
cp -R "$NOTES_CHART"/. "$REUSED_CHART"/
yq -i 'del(.apisix.dataEncryption)' "$REUSED_CHART/values.yaml" || exit 2
ORIGINAL_CHART=$CHART
CHART=$REUSED_CHART
NOTES_CHART=$REUSED_CHART

check "reuse-values: renders without the new map" render
check "reuse-values: encryption stays enabled" is "$(config '.apisix.data_encryption.enable_encrypt_fields')" true
check "reuse-values: keeps the built-in keyring" is "$(config '.apisix.data_encryption.keyring')" null
check "reuse-values: no keyring environment variable" is "$(key_envs)" ""
check "reuse-values: NOTES still warns" warns
check "reuse-values, disabled: renders" render --set apisix.dataEncryption.enableEncryptFields=false
check "reuse-values: explicit false is preserved" is "$(config '.apisix.data_encryption.enable_encrypt_fields')" false
check "reuse-values, disabled: NOTES still warns for SSL keys" warns --set apisix.dataEncryption.enableEncryptFields=false
check "reuse-values, secret: renders with only secretName" render --set apisix.dataEncryption.secretName=apisix-keyring
check "reuse-values, secret: defaults to key1" is "$(env_ref APISIX_DATA_ENCRYPTION_KEY_1)" apisix-keyring/key1
check "reuse-values, secret: config refers to the variable" is "$(config '.apisix.data_encryption.keyring | join(",")')" '${{APISIX_DATA_ENCRYPTION_KEY_1}}'
check "reuse-values, secret: no built-in warning" does_not_warn --set apisix.dataEncryption.secretName=apisix-keyring
check "reuse-values: explicit empty secretKeys still fails" fails_with "apisix.dataEncryption.secretKeys must list the keys" \
  --set apisix.dataEncryption.secretName=apisix-keyring --set-json 'apisix.dataEncryption.secretKeys=[]'
check "reuse-values, inline: renders" render --set-json "apisix.dataEncryption.keyring=[\"$NEW\",\"$BUILTIN_1\"]"
check "reuse-values, inline: keeps key order" is "$(config '.apisix.data_encryption.keyring | join(",")')" "$NEW,$BUILTIN_1"
check "reuse-values, fullCustomConfig: renders" render "${CUSTOM_CONFIG[@]}" --set apisix.dataEncryption.secretName=apisix-keyring
check "reuse-values, fullCustomConfig: still injects the Secret key" is "$(env_ref APISIX_DATA_ENCRYPTION_KEY_1)" apisix-keyring/key1

CHART=$ORIGINAL_CHART
NOTES_CHART=$ORIGINAL_NOTES_CHART

# --- a keyring in the values ---------------------------------------------------

check "inline: renders" render --set-json "apisix.dataEncryption.keyring=[\"$NEW\",\"$BUILTIN_1\",\"$BUILTIN_2\"]"
check "inline: the keyring is rendered in order" is "$(config '.apisix.data_encryption.keyring | join(",")')" "$NEW,$BUILTIN_1,$BUILTIN_2"
check "inline: the keys are quoted" grep -qF -- "- \"$NEW\"" <<<"$(config_text)"
check "inline: no warning about the built-in keyring" does_not_warn --set-json "apisix.dataEncryption.keyring=[\"$NEW\"]"

check "inline, digits only: renders" render --set-json 'apisix.dataEncryption.keyring=["1234567890123456"]'
check "inline: a key made of digits stays a string" is "$(config '.apisix.data_encryption.keyring[0] | tag')" '!!str'

check "disabled: renders" render --set apisix.dataEncryption.enableEncryptFields=false
check "disabled: enable_encrypt_fields is rendered false" is "$(config '.apisix.data_encryption.enable_encrypt_fields')" false
check "disabled: still warns, SSL private keys are encrypted with the keyring" warns --set apisix.dataEncryption.enableEncryptFields=false

# --- a keyring in an existing Secret -------------------------------------------

check "secret: renders" render --set apisix.dataEncryption.secretName=apisix-keyring
check "secret: one key by default" is "$(key_envs)" APISIX_DATA_ENCRYPTION_KEY_1
check "secret: it reads the key key1" is "$(env_ref APISIX_DATA_ENCRYPTION_KEY_1)" apisix-keyring/key1
check "secret: config.yaml refers to the variable" is "$(config '.apisix.data_encryption.keyring | join(",")')" '${{APISIX_DATA_ENCRYPTION_KEY_1}}'

check "secret with two keys: renders" render --set apisix.dataEncryption.secretName=apisix-keyring --set-json 'apisix.dataEncryption.secretKeys=["new","old"]'
check "secret: one variable per key, in keyring order" is "$(env_ref APISIX_DATA_ENCRYPTION_KEY_1),$(env_ref APISIX_DATA_ENCRYPTION_KEY_2)" apisix-keyring/new,apisix-keyring/old
check "secret: config.yaml lists the variables in the same order" is "$(config '.apisix.data_encryption.keyring | join(",")')" '${{APISIX_DATA_ENCRYPTION_KEY_1}},${{APISIX_DATA_ENCRYPTION_KEY_2}}'
check "secret: no warning about the built-in keyring" does_not_warn --set apisix.dataEncryption.secretName=apisix-keyring

check "secret with fullCustomConfig: renders" render "${CUSTOM_CONFIG[@]}" --set apisix.dataEncryption.secretName=apisix-keyring
check "secret with fullCustomConfig: the variable is still set for the custom config" is "$(env_ref APISIX_DATA_ENCRYPTION_KEY_1)" apisix-keyring/key1

# --- values that cannot work -----------------------------------------------------

check "fail: the first key is the first built-in key" fails_with "the first key, which APISIX encrypts with, is one of the built-in keys" \
  --set-json "apisix.dataEncryption.keyring=[\"$BUILTIN_1\",\"$NEW\"]"
check "fail: the first key is the second built-in key" fails_with "the first key, which APISIX encrypts with, is one of the built-in keys" \
  --set-json "apisix.dataEncryption.keyring=[\"$BUILTIN_2\"]"
values=$(mktemp)
printf 'apisix:\n  dataEncryption:\n    keyring:\n      - %s\n      - 1234567890123456\n' "$NEW" >"$values"
check "fail: an unquoted number in the keyring" fails_with "apisix.dataEncryption.keyring: entry 2 is not a string" -f "$values"
check "fail: the error does not print the key" bash -c '! grep -qF 1234567890123456 <<<"$1"' _ "$ERR"
rm -f "$values"
check "fail: a keyring given as one string" fails_with "apisix.dataEncryption.keyring must be a list of keys" \
  --set apisix.dataEncryption.keyring="$NEW"
check "fail: that error does not print the key" bash -c '! grep -qF "$2" <<<"$1"' _ "$ERR" "$NEW"
check "fail: a key that is not 16 or 32 bytes long" fails_with "entry 2 is 15 bytes long" \
  --set-json "apisix.dataEncryption.keyring=[\"$NEW\",\"${NEW:0:15}\"]"
check "fail: that error does not print the key" bash -c '! grep -qF "$2" <<<"$1"' _ "$ERR" "${NEW:0:15}"
check "a 32-byte key: renders" render --set-json "apisix.dataEncryption.keyring=[\"$NEW$NEW\"]"
check "fail: an inline keyring with fullCustomConfig" fails_with "apisix.dataEncryption.keyring is not used with apisix.fullCustomConfig" \
  "${CUSTOM_CONFIG[@]}" --set-json "apisix.dataEncryption.keyring=[\"$NEW\"]"
check "fail: keyring and secretName together" fails_with "set either keyring or secretName, not both" \
  --set-json "apisix.dataEncryption.keyring=[\"$NEW\"]" --set apisix.dataEncryption.secretName=apisix-keyring
check "fail: secretName without secretKeys" fails_with "apisix.dataEncryption.secretKeys must list the keys" \
  --set apisix.dataEncryption.secretName=apisix-keyring --set-json 'apisix.dataEncryption.secretKeys=[]'

# --- when the warning applies -----------------------------------------------------

check "standalone (file): no warning, APISIX does not encrypt without etcd" does_not_warn --set apisix.deployment.mode=standalone
check "standalone (API): no warning, APISIX does not encrypt without etcd" does_not_warn --set apisix.deployment.role_traditional.config_provider=yaml --set etcd.enabled=false
check "fullCustomConfig: no warning, the custom config decides" does_not_warn "${CUSTOM_CONFIG[@]}"
check "decoupled data plane: warns, it decrypts with the same keyring" warns --set apisix.deployment.mode=decoupled --set apisix.deployment.role=data_plane
check "decoupled control plane: warns" warns --set apisix.deployment.mode=decoupled --set apisix.deployment.role=control_plane
check "the old apisix.data_encryption value: NOTES says it is not read" \
  notes_say "apisix.data_encryption is not read by this chart" --set-json 'apisix.data_encryption={"keyring":["AbCdEfGhIjKlMnOp"]}'

echo
echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
