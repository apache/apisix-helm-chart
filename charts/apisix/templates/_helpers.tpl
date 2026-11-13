{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "apisix.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "apisix.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "apisix.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "apisix.labels" -}}
helm.sh/chart: {{ include "apisix.chart" . }}
{{ include "apisix.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "apisix.selectorLabels" -}}
{{- if .Values.service.labelsOverride }}
{{- tpl (.Values.service.labelsOverride | toYaml) . }}
{{- else }}
app.kubernetes.io/name: {{ include "apisix.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "apisix.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "apisix.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Renders a value that contains template.
Usage:
{{ include "apisix.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "apisix.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{- define "apisix.basePluginAttrs" -}}
{{- if .Values.apisix.prometheus.enabled }}
prometheus:
  export_addr:
    ip: 0.0.0.0
    port: {{ .Values.apisix.prometheus.containerPort }}
  export_uri: {{ .Values.apisix.prometheus.path }}
  metric_prefix: {{ .Values.apisix.prometheus.metricPrefix }}
{{- end }}
{{- if .Values.apisix.customPlugins.enabled }}
{{- range $plugin := .Values.apisix.customPlugins.plugins }}
{{- if $plugin.attrs }}
{{ $plugin.name }}: {{- $plugin.attrs | toYaml | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "apisix.pluginAttrs" -}}
{{- merge .Values.apisix.pluginAttrs (include "apisix.basePluginAttrs" . | fromYaml) | toYaml -}}
{{- end -}}

{{/*
Scheme to use while connecting etcd
*/}}
{{- define "apisix.etcd.auth.scheme" -}}
{{- if .Values.etcd.auth.tls.enabled }}
{{- "https" }}
{{- else }}
{{- "http" }}
{{- end }}
{{- end }}

{{/*
Return true when etcd client certificates are configured, otherwise an empty string.
Validate the credentials used by the generated APISIX configuration.
*/}}
{{- define "apisix.etcd.tls.clientCertEnabled" -}}
{{- $tls := .Values.etcd.auth.tls -}}
{{- if and $tls.enabled (or $tls.certFilename $tls.certKeyFilename) -}}
{{- if not (and $tls.certFilename $tls.certKeyFilename) -}}
{{- fail "etcd.auth.tls.certFilename and etcd.auth.tls.certKeyFilename must be set together" -}}
{{- end -}}
{{- if not $tls.existingSecret -}}
{{- fail "etcd.auth.tls.existingSecret is required when configuring etcd client certificates" -}}
{{- end -}}
true
{{- end -}}
{{- end -}}

{{/*
Return the name of etcd password secret
*/}}
{{- define "apisix.etcd.secretName" -}}
{{- if and .Values.etcd.enabled .Values.etcd.auth.rbac.create }}
{{- include "etcd.secretName" .Subcharts.etcd }}
{{- else if .Values.externalEtcd.existingSecret }}
{{- print .Values.externalEtcd.existingSecret }}
{{- else if .Values.externalEtcd.user }}
{{- printf "etcd-%s" (include "apisix.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end -}}

{{/*
Return the password key name of etcd secret
*/}}
{{- define "apisix.etcd.secretPasswordKey" -}}
{{- if .Values.etcd.enabled }}
{{- include "etcd.secretPasswordKey" .Subcharts.etcd }}
{{- else }}
{{- print .Values.externalEtcd.secretPasswordKey }}
{{- end }}
{{- end -}}

{{/*
The label that lets pods through the NetworkPolicy of the bundled etcd:
`<etcd fullname>-client`, as the etcd chart writes it. A label key has at most
63 characters, so a longer one is shortened; "apisix.etcd.validate" makes sure
that this only happens when the NetworkPolicy does not use the label.
Call it with the context of the etcd chart.
*/}}
{{- define "apisix.etcd.clientLabel" -}}
{{- printf "%s-client" (include "common.names.fullname" . | trunc 56 | trimSuffix "-") -}}
{{- end -}}

{{/*
Fail on values for the bundled etcd that would open it to every pod, or that
its NetworkPolicy cannot handle.
*/}}
{{- define "apisix.etcd.validate" -}}
{{- if .Values.etcd.enabled -}}
{{- $etcd := .Subcharts.etcd.Values -}}
{{- /* values.yaml gives each job of the etcd chart the client label, with a key
     that the etcd chart renders. helm upgrade --reuse-values from a chart
     version before 3.0.0 renders with the default values of that version,
     which have none of these entries and leave etcd open to every pod; before
     2.12 they even turn the NetworkPolicy off, so this check does not depend
     on it. Look for the key as it is written in values.yaml */}}
{{- $clientLabelKey := "{{ include \"apisix.etcd.clientLabel\" . }}" -}}
{{- $preUpgradeJobLabelled := hasKey (get $etcd.preUpgradeJob "podLabels" | default dict) $clientLabelKey -}}
{{- $cronJobsLabelled := or (hasKey (dig "cronjob" "podLabels" dict $etcd.disasterRecovery) $clientLabelKey) (hasKey (dig "cronjob" "podLabels" dict $etcd.defrag) $clientLabelKey) -}}
{{- $clientLabel := include "apisix.etcd.clientLabel" .Subcharts.etcd -}}
{{- if not (or $preUpgradeJobLabelled $cronJobsLabelled) -}}
{{- fail (printf "None of the podLabels of the etcd chart's jobs (etcd.preUpgradeJob, etcd.disasterRecovery.cronjob and etcd.defrag.cronjob) has the entry that this chart's values.yaml sets there for the label %s, so the values of this release probably come from an earlier chart version. helm upgrade --reuse-values does that, and so does spec.upgrade.preserveValues: true in Flux: Helm then renders with the default values of the chart version you upgrade from, which before 3.0.0 leave etcd open to every pod. Upgrade with --reset-then-reuse-values (Helm 3.14 or later) or pass your values again with -f; in Flux, set spec.upgrade.preserveValues: false" $clientLabel) -}}
{{- end -}}
{{- if and $etcd.networkPolicy.enabled (not $etcd.networkPolicy.allowExternal) -}}
{{- /* the CronJobs need no such check: the etcd chart itself fails to render
     their podLabels when they are removed */}}
{{- if and $etcd.preUpgradeJob.enabled (not $preUpgradeJobLabelled) -}}
{{- fail (printf "etcd.preUpgradeJob.podLabels lacks the entry that this chart's values.yaml sets there for the label %s, so the pre-upgrade job of the bundled etcd could not reach etcd, and the next upgrade would fail. Keep that entry, turn the job off, or set etcd.networkPolicy.allowExternal: true" $clientLabel) -}}
{{- end -}}
{{- $label := printf "%s-client" (include "common.names.fullname" .Subcharts.etcd) -}}
{{- if gt (len $label) 63 -}}
{{- fail (printf "The NetworkPolicy of the bundled etcd admits pods labelled %s, but a label key has at most 63 characters. For a new release, use a shorter release name or etcd.fullnameOverride (APISIX does not find etcd under an etcd.nameOverride); otherwise set etcd.networkPolicy.allowExternal: true" $label) -}}
{{- end -}}
{{- if and $etcd.metrics.enabled (not $etcd.metrics.useSeparateEndpoint) -}}
{{- fail "etcd.metrics.enabled serves the metrics on the etcd client port, and the etcd chart then opens that port to every pod. Set etcd.metrics.useSeparateEndpoint: true to serve them on a port of their own, or etcd.networkPolicy.allowExternal: true" -}}
{{- end -}}
{{- if .Values.hostNetwork -}}
{{- /* only an ipBlock peer, or a rule without "from", can admit the addresses
     of the nodes; rules written as a templated string cannot be checked */}}
{{- $extraIngress := $etcd.networkPolicy.extraIngress -}}
{{- $admitsNodes := false -}}
{{- if kindIs "slice" $extraIngress -}}
{{- range $rule := $extraIngress -}}
{{- if empty (get $rule "from") -}}{{- $admitsNodes = true -}}{{- end -}}
{{- range $peer := get $rule "from" | default list -}}
{{- if hasKey $peer "ipBlock" -}}{{- $admitsNodes = true -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if not $admitsNodes -}}
{{- fail "hostNetwork: true: most network plugins cannot select pods in the host network by their labels, so the NetworkPolicy of the bundled etcd would drop the connections of the APISIX pods. Add a rule to etcd.networkPolicy.extraIngress, written as a list, with an ipBlock for the addresses the nodes connect from, or set etcd.networkPolicy.allowExternal: true; on Cilium, which by default does not match nodes with ipBlock rules, use allowExternal. See \"Access to the bundled etcd\" in the README" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Key to use to fetch admin token from secret
*/}}
{{- define "apisix.admin.credentials.secretAdminKey" -}}
{{- if .Values.apisix.admin.credentials.secretAdminKey }}
{{- .Values.apisix.admin.credentials.secretAdminKey }}
{{- else }}
{{- "admin" }}
{{- end }}
{{- end }}

{{/*
Key to use to fetch viewer token from secret
*/}}
{{- define "apisix.admin.credentials.secretViewerKey" -}}
{{- if .Values.apisix.admin.credentials.secretViewerKey }}
{{- .Values.apisix.admin.credentials.secretViewerKey }}
{{- else }}
{{- "viewer" }}
{{- end }}
{{- end }}

{{/*
Publicly known Admin API keys that chart versions before 3.0.0 used as
defaults. The chart rejects them wherever it can see a configured key.
*/}}
{{- define "apisix.admin.credentials.publicDefaults" -}}
edd1c9f034335f136f87ad84b625c8f1 4054f7cf07e344346cd3f287985e76a2
{{- end -}}

{{/*
Returns "true" when this release renders Admin API keys: only the
traditional and control_plane roles have an Admin API, and
apisix.fullCustomConfig replaces the rendered configuration.
*/}}
{{- define "apisix.admin.credentials.enabled" -}}
{{- if and (ne (include "apisix.deployment.role" .) "data_plane") (not .Values.apisix.fullCustomConfig.enabled) -}}
true
{{- end -}}
{{- end -}}

{{/*
Name of the Secret that holds the keys the chart generates.
*/}}
{{- define "apisix.admin.credentials.generatedSecretName" -}}
{{- printf "%s-admin-credentials" (include "apisix.fullname" .) -}}
{{- end -}}

{{/*
Where a key comes from. Call with (dict "role" "admin|viewer" "context" $).
  secret     the Secret named in apisix.admin.credentials.secretName
  inline     the value of apisix.admin.credentials.<role>
  generated  the Secret the chart generates (the value is empty)
*/}}
{{- define "apisix.admin.credentials.source" -}}
{{- $c := .context.Values.apisix.admin.credentials -}}
{{- if $c.secretName -}}
secret
{{- else if index $c .role -}}
inline
{{- else -}}
generated
{{- end -}}
{{- end -}}

{{/*
Returns "true" when the chart generates at least one key.
*/}}
{{- define "apisix.admin.credentials.generated" -}}
{{- if include "apisix.admin.credentials.enabled" . -}}
{{- range $role := list "admin" "viewer" -}}
{{- if eq (include "apisix.admin.credentials.source" (dict "role" $role "context" $)) "generated" -}}
true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Data of the generated Secret, as YAML. A key already stored in the Secret is
kept, so helm upgrade never changes it; a stored key that is one of the public
defaults fails the release. A missing key is generated on
install. On upgrade a missing key fails the release instead: generating a new
one would cut off every Admin API client, and the usual cause is a release
installed with a chart version that used the public default keys.
lookup returns nothing when the chart is rendered without access to the
cluster (helm template, client-side --dry-run, Argo CD), so a new key is
generated on every such render; those setups need
apisix.admin.credentials.secretName.
*/}}
{{- define "apisix.admin.credentials.generatedData" -}}
{{- $name := include "apisix.admin.credentials.generatedSecretName" . -}}
{{- $existing := (lookup "v1" "Secret" .Release.Namespace $name).data | default dict -}}
{{- $public := splitList " " (include "apisix.admin.credentials.publicDefaults" .) -}}
{{- $data := dict -}}
{{- range $role := list "admin" "viewer" -}}
{{- if eq (include "apisix.admin.credentials.source" (dict "role" $role "context" $)) "generated" -}}
{{- $current := "" -}}
{{- if hasKey $existing $role -}}
{{- $current = index $existing $role | b64dec -}}
{{- end -}}
{{- if has $current $public -}}
{{- fail (printf "\nADMIN KEY ERROR: the %s key in the Secret %s/%s is a publicly known default key. Store a different key in the Secret." $role $.Release.Namespace $name) -}}
{{- else if $current -}}
{{- $_ := set $data $role (index $existing $role) -}}
{{- else if and $.Release.IsUpgrade $.Values.apisix.admin.enabled (include "apisix.lookupAvailable" $) -}}
{{- fail (printf "\nADMIN KEY ERROR: the Secret %s/%s does not contain the %s key that this chart generates, so this upgrade would replace the key and cut off every Admin API client.\nThis happens when the release was installed with a chart version before 3.0.0, when it took its keys from apisix.admin.credentials or had no Admin API before, or when the key or the Secret was deleted.\nSet the keys and upgrade again, with one of:\n  --set apisix.admin.credentials.admin=<key> --set apisix.admin.credentials.viewer=<key>\n  --set apisix.admin.credentials.secretName=<a Secret with the keys \"admin\" and \"viewer\">\nUse the keys your Admin API clients already have to keep them working; a release that used the public default keys of earlier chart versions needs new ones. The bundled ingress controller picks up the admin key automatically. To let the chart manage existing keys instead, see \"Admin API keys\" in the chart README." $.Release.Namespace $name $role) -}}
{{- else -}}
{{- $_ := set $data $role (randAlphaNum 32 | b64enc) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $data -}}
{{- end -}}

{{/*
Returns "true" when chart versions before 3.0.0, which rendered keys unquoted,
would have read the key differently: YAML dropped leading and trailing spaces,
tabs and line breaks (for example the newline at the end of a file passed with
--set-file), the quotes around a key that starts with one, and a " #" with
everything after it. The key is now used exactly as given, so such a key would
silently differ from the one clients send.
*/}}
{{- define "apisix.admin.credentials.ambiguous" -}}
{{- if or (ne . (trimAll " \t\r\n" .)) (regexMatch "^[\"']|[ \t]#" .) -}}
true
{{- end -}}
{{- end -}}

{{/*
Returns "true" when lookup reads the cluster. A real upgrade normally finds the
ConfigMap kube-root-ca.crt (published into every namespace since Kubernetes
1.20, unless that controller is turned off), this release's own ConfigMap, or
Helm's record of the previous revision (Secret or ConfigMap storage driver).
None of them is found when Helm renders without the cluster: helm template
(also with --is-upgrade), helm upgrade --dry-run=client, and helm diff on
Helm 3. The upgrade check needs this: without it, such previews would fail with
an error that asks for new keys.
*/}}
{{- define "apisix.lookupAvailable" -}}
{{- $ns := .Release.Namespace -}}
{{- $previous := printf "sh.helm.release.v1.%s.v%d" .Release.Name (sub (int .Release.Revision) 1) -}}
{{- if or (lookup "v1" "ConfigMap" $ns "kube-root-ca.crt") (lookup "v1" "ConfigMap" $ns (include "apisix.fullname" .)) (lookup "v1" "Secret" $ns $previous) (lookup "v1" "ConfigMap" $ns $previous) -}}
true
{{- end -}}
{{- end -}}

{{/*
Fails when a configured key is one of the publicly known defaults: in
apisix.admin.credentials, in apisix.fullCustomConfig.config, or in the Secret
named by apisix.admin.credentials.secretName. That Secret is checked only when
it can be read (lookup returns nothing under helm template).
*/}}
{{- define "apisix.admin.credentials.validate" -}}
{{- $c := .Values.apisix.admin.credentials -}}
{{- $public := splitList " " (include "apisix.admin.credentials.publicDefaults" .) -}}
{{- if .Values.apisix.fullCustomConfig.enabled -}}
{{- /* the ConfigMap renders this config with tpl, so check the rendered text */ -}}
{{- $rendered := include "apisix.tplvalues.render" (dict "value" .Values.apisix.fullCustomConfig.config "context" .) -}}
{{- range $key := $public -}}
{{- if contains $key $rendered -}}
{{- fail "\nADMIN KEY ERROR: apisix.fullCustomConfig.config contains a publicly known default Admin API key. Use a different key." -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $c.secretName -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace $c.secretName).data | default dict -}}
{{- $fields := dict "admin" (include "apisix.admin.credentials.secretAdminKey" .) "viewer" (include "apisix.admin.credentials.secretViewerKey" .) -}}
{{- range $role, $field := $fields -}}
{{- if and (hasKey $secret $field) (has (index $secret $field | b64dec) $public) -}}
{{- fail (printf "\nADMIN KEY ERROR: the %s key in the Secret %s (field %q) is a publicly known default key. Store a different key in the Secret." $role $c.secretName $field) -}}
{{- end -}}
{{- end -}}
{{- else if include "apisix.admin.credentials.enabled" . -}}
{{- range $role := list "admin" "viewer" -}}
{{- $key := toString (index $c $role) -}}
{{- if has $key $public -}}
{{- fail (printf "\nADMIN KEY ERROR: apisix.admin.credentials.%s is a publicly known default key. Set a different key, or leave it empty to let the chart generate one." $role) -}}
{{- else if and (index $c $role) (include "apisix.admin.credentials.ambiguous" $key) -}}
{{- fail (printf "\nADMIN KEY ERROR: apisix.admin.credentials.%s starts or ends with whitespace, starts with a quote, or contains a space followed by #. Chart versions before 3.0.0 dropped these parts of the key; this version uses the key exactly as given, so clients would no longer match it. Remove them (a file passed with --set-file must not end with a newline)." $role) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Name of the GatewayProxy that the bundled controller's IngressClass references
(ingress-controller.gatewayProxy.name, rendered with tpl). Empty when the user
sets it to "".
*/}}
{{- define "apisix.ingressController.gatewayProxy.name" -}}
{{- $gp := (index .Values "ingress-controller").gatewayProxy -}}
{{- tpl ($gp.name | default "" | toString) . -}}
{{- end -}}

{{/*
Returns "true" when the apisix chart creates the GatewayProxy for the bundled
ingress controller: the controller is enabled, the controller chart is not
asked to create its own (gatewayProxy.createDefault), the IngressClass
references a GatewayProxy, and this release has an Admin API.
*/}}
{{- define "apisix.ingressController.gatewayProxy.enabled" -}}
{{- $ic := index .Values "ingress-controller" -}}
{{- if and $ic.enabled (not $ic.gatewayProxy.createDefault) (include "apisix.ingressController.gatewayProxy.name" .) .Values.apisix.admin.enabled (include "apisix.admin.credentials.enabled" .) -}}
true
{{- end -}}
{{- end -}}

{{/*
Checks the bundled ingress controller's GatewayProxy.
With gatewayProxy.createDefault, the controller chart creates the GatewayProxy:
it needs an admin key that is not a public default. When it targets this
release's Admin API Service <fullname>-admin (through service.name or
apisix.adminService.name, or endpoints that name that Service), the release
needs an Admin API, and the key must come from where APISIX takes it unless
fullCustomConfig hides it. A release with its own Admin API that falls back to
the default name apisix-admin, which is not its Service, is misconfigured;
a data-plane release may point at a control plane's apisix-admin. Without
this check the controller cannot reach the Admin API and APISIX never becomes
ready (apache/apisix-helm-chart#908).
Without createDefault, this chart creates the GatewayProxy, which needs an
Admin API in this release; otherwise the IngressClass would reference a
GatewayProxy that does not exist.
*/}}
{{- define "apisix.ingressController.validate" -}}
{{- $ic := index .Values "ingress-controller" -}}
{{- if $ic.enabled -}}
{{- $gp := $ic.gatewayProxy -}}
{{- if $gp.createDefault -}}
{{- $adminKey := $gp.provider.controlPlane.auth.adminKey -}}
{{- $public := splitList " " (include "apisix.admin.credentials.publicDefaults" .) -}}
{{- if not $adminKey.valueFrom -}}
{{- if not $adminKey.value -}}
{{- fail "\nINGRESS CONTROLLER ERROR: ingress-controller.gatewayProxy.createDefault is true, but no admin key is set for the GatewayProxy it creates.\nRemove ingress-controller.gatewayProxy.createDefault to let the apisix chart create the GatewayProxy with this release's key, or set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey." -}}
{{- else if has (toString $adminKey.value) $public -}}
{{- fail "\nINGRESS CONTROLLER ERROR: ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value is a publicly known default key. Use a different key." -}}
{{- else if ne (toString $adminKey.value) (trimAll " \t\r\n" (toString $adminKey.value)) -}}
{{- fail "\nINGRESS CONTROLLER ERROR: ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey.value starts or ends with whitespace, which would become part of the key. Remove it (a file passed with --set-file must not end with a newline)." -}}
{{- end -}}
{{- end -}}
{{- $cp := $gp.provider.controlPlane -}}
{{- /* the Service the controller chart's gatewayproxy.yaml uses when there are no endpoints */ -}}
{{- $localService := printf "%s-admin" (include "apisix.fullname" .) -}}
{{- $explicitService := ($cp.service | default dict).name | default "" | toString -}}
{{- $fallbackService := (($ic.apisix | default dict).adminService | default dict).name | default "" | toString -}}
{{- $service := default $fallbackService $explicitService -}}
{{- $targetsLocal := false -}}
{{- if $cp.endpoints -}}
{{- /* <service>, <service>.<namespace>, <service>.<namespace>.svc[.<cluster domain>], optional trailing dot */ -}}
{{- $localHost := printf "^%s(\\.%s(\\.svc(\\.[a-z0-9.-]+)?)?)?\\.?$" (regexQuoteMeta $localService) (regexQuoteMeta .Release.Namespace) -}}
{{- range $endpoint := $cp.endpoints -}}
{{- $url := toString $endpoint | trim -}}
{{- $host := regexReplaceAll "^[A-Za-z][A-Za-z0-9+.-]*://([^@/?#]*@)?([^:/?#]*).*$" $url "${2}" -}}
{{- if and (ne $host $url) (regexMatch $localHost (lower $host)) -}}
{{- $targetsLocal = true -}}
{{- end -}}
{{- end -}}
{{- else -}}
{{- $targetsLocal = eq $service $localService -}}
{{- end -}}
{{- $hasAdminApi := and .Values.apisix.admin.enabled (ne (include "apisix.deployment.role" .) "data_plane") -}}
{{- if $targetsLocal -}}
{{- if not $hasAdminApi -}}
{{- fail (printf "\nINGRESS CONTROLLER ERROR: the GatewayProxy that ingress-controller.gatewayProxy.createDefault creates targets %s, the Admin API Service of this release, but this release has no Admin API.\nPoint it at your control plane with ingress-controller.gatewayProxy.provider.controlPlane.endpoints or service.name, or remove createDefault." $localService) -}}
{{- end -}}
{{- if include "apisix.admin.credentials.enabled" . -}}
{{- /* with fullCustomConfig the chart cannot see the key APISIX uses */ -}}
{{- $source := include "apisix.admin.credentials.source" (dict "role" "admin" "context" .) -}}
{{- $match := false -}}
{{- if eq $source "inline" -}}
{{- $match = and (not $adminKey.valueFrom) (eq (toString $adminKey.value) (toString .Values.apisix.admin.credentials.admin)) -}}
{{- else -}}
{{- $ref := ($adminKey.valueFrom | default dict).secretKeyRef | default dict -}}
{{- $expectedName := ternary .Values.apisix.admin.credentials.secretName (include "apisix.admin.credentials.generatedSecretName" .) (eq $source "secret") -}}
{{- $expectedKey := ternary (include "apisix.admin.credentials.secretAdminKey" .) "admin" (eq $source "secret") -}}
{{- $match = and (eq (toString $ref.name) $expectedName) (eq (toString $ref.key) $expectedKey) -}}
{{- end -}}
{{- if not $match -}}
{{- fail "\nINGRESS CONTROLLER ERROR: ingress-controller.gatewayProxy.createDefault is true, but the GatewayProxy that it creates would not use the Admin API key of this release, so the controller could not reach APISIX.\nRemove ingress-controller.gatewayProxy.createDefault: the apisix chart creates the GatewayProxy and gives it the right key.\nTo keep managing the GatewayProxy yourself, set ingress-controller.gatewayProxy.provider.controlPlane.auth.adminKey to the same key as apisix.admin.credentials: the same value, or a secretKeyRef to the same Secret and field." -}}
{{- end -}}
{{- end -}}
{{- else if and (not $cp.endpoints) (not $explicitService) (eq $fallbackService "apisix-admin") $hasAdminApi (include "apisix.admin.credentials.enabled" .) -}}
{{- /* this release has its own Admin API, but the controller would fall back to the chart default Service name */ -}}
{{- fail (printf "\nINGRESS CONTROLLER ERROR: the GatewayProxy that ingress-controller.gatewayProxy.createDefault creates would use the Service %s (the controller chart's default), but the Admin API Service of this release is %s.\nRemove createDefault to let the apisix chart create the GatewayProxy, or set ingress-controller.gatewayProxy.provider.controlPlane.service.name." $service $localService) -}}
{{- end -}}
{{- else if and (include "apisix.ingressController.gatewayProxy.name" .) (not (include "apisix.ingressController.gatewayProxy.enabled" .)) -}}
{{- fail (printf "\nINGRESS CONTROLLER ERROR: the bundled ingress controller's IngressClass references the GatewayProxy %s, but this release cannot create it because it has no Admin API (data_plane role, apisix.fullCustomConfig, or apisix.admin.enabled=false).\nSet ingress-controller.gatewayProxy.createDefault=true with the Admin API endpoints and key of your control plane, set ingress-controller.gatewayProxy.name=\"\" to leave the IngressClass without a GatewayProxy, or disable the controller." (include "apisix.ingressController.gatewayProxy.name" .)) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
The deployment role APISIX runs with. mode "standalone" is file-driven
standalone: rules come from the mounted apisix.yaml, which APISIX reads as a
data plane with the yaml config provider. With the default traditional role on
the etcd provider that combination could never start (no etcd is configured in
standalone mode), so it is rendered as a data plane. A traditional role on the
yaml provider (API-driven standalone) is kept as configured; a control plane
needs etcd and cannot run standalone.
*/}}
{{- define "apisix.deployment.role" -}}
{{- $role := .Values.apisix.deployment.role -}}
{{- if eq .Values.apisix.deployment.mode "standalone" -}}
{{- if eq $role "control_plane" -}}
{{- fail "apisix.deployment.mode \"standalone\" cannot run with apisix.deployment.role \"control_plane\": a control plane needs etcd" -}}
{{- end -}}
{{- if and (eq $role "traditional") (ne (default "etcd" .Values.apisix.deployment.role_traditional.config_provider) "yaml") -}}
{{- $role = "data_plane" -}}
{{- end -}}
{{- end -}}
{{- $role -}}
{{- end -}}
