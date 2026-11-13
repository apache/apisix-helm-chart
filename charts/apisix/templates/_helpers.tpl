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
{{- $base := .Release.Name }}
{{- if .componentName }}{{ printf "%s-%s" $base .componentName | trunc 63 | trimSuffix "-" }}{{ else }}{{ $base | trunc 63 | trimSuffix "-" }}{{ end }}
{{- else }}
{{- $base := printf "%s-%s" .Release.Name $name }}
{{- if .componentName }}{{ printf "%s-%s" $base .componentName | trunc 63 | trimSuffix "-" }}{{ else }}{{ $base | trunc 63 | trimSuffix "-" }}{{ end }}
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
app.kubernetes.io/name: {{ include "apisix.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .componentName }}
app.kubernetes.io/component: {{ .componentName }}
{{- end }}
{{- with .Values.service.labelsOverride }}
{{- tpl (. | toYaml) $ }}
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


{{/* Return the replica count for the selected component. */}}
{{- define "apisix.replicaCount" -}}
{{- if eq .componentName "control-plane" -}}{{ .Values.apisix.deployment.controlPlane.replicaCount }}
{{- else if eq .componentName "data-plane" -}}{{ .Values.apisix.deployment.dataPlane.replicaCount }}
{{- else -}}{{ .Values.replicaCount }}{{- end -}}
{{- end -}}
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
{{- if .Values.etcd.fullnameOverride }}{{ .Values.etcd.fullnameOverride }}{{ else }}{{ printf "%s-etcd" .Release.Name }}{{ end }}
{{- else if .Values.externalEtcd.existingSecret }}
{{- print .Values.externalEtcd.existingSecret }}
{{- else if .Values.externalEtcd.user }}
{{- printf "etcd-%s-apisix" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end -}}

{{/*
Return the password key name of etcd secret
*/}}
{{- define "apisix.etcd.secretPasswordKey" -}}
{{- if .Values.etcd.enabled }}
{{- print "etcd-root-password" }}
{{- else }}
{{- print .Values.externalEtcd.secretPasswordKey }}
{{- end }}
{{- end -}}

{{/* Return the Admin API credential Secret name. */}}
{{- define "apisix.admin.credentials.secretName" -}}
{{- if .Values.apisix.admin.credentials.secretName -}}
{{- .Values.apisix.admin.credentials.secretName -}}
{{- else -}}
{{- printf "%s-admin-credentials" (include "apisix.fullname" .) | trunc 63 | trimSuffix "-" -}}
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
The deployment role APISIX runs with. mode "standalone" is file-driven
standalone: rules come from the mounted apisix.yaml, which APISIX reads as a
data plane with the yaml config provider. With the default traditional role on
the etcd provider that combination could never start (no etcd is configured in
standalone mode), so it is rendered as a data plane. A traditional role on the
yaml provider (API-driven standalone) is kept as configured; a control plane
needs etcd and cannot run standalone.
*/}}
{{- define "apisix.deployment.role" -}}
{{- $role := default .Values.apisix.deployment.role .componentRole -}}
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
