{{- define "apisix.podTemplate" -}}
metadata:
  annotations:
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    {{- if .Values.podAnnotations }}
    {{- range $key, $value := $.Values.podAnnotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
    {{- end }}
  labels:
    {{- include "apisix.selectorLabels" . | nindent 4 }}
spec:
  {{- with .Values.global.imagePullSecrets }}
  imagePullSecrets:
    {{- range $.Values.global.imagePullSecrets }}
    - name: {{ . }}
    {{- end }}
  {{- end }}
  serviceAccountName: {{ include "apisix.serviceAccountName" . }}
  {{- with .Values.podSecurityContext }}
  securityContext: 
    {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .Values.priorityClassName }}
  priorityClassName: {{ . }}
  {{- end }}
  containers:
    - name: {{ .Chart.Name }}
      {{- with .Values.securityContext }}
      securityContext:
        {{- . | toYaml | nindent 8 }}
      {{- end }}
      image: "{{ .Values.image.repository }}:{{ default .Chart.AppVersion .Values.image.tag }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      env:
      {{- if .Values.timezone }}
        - name: TZ
          value: {{ .Values.timezone }}
      {{- end }}
      {{- if .Values.extraEnvVars }}
      {{- include "apisix.tplvalues.render" (dict "value" .Values.extraEnvVars "context" $) | nindent 8 }}
      {{- end }}

      {{- if .Values.apisix.admin.credentials.secretName }}
        - name: APISIX_ADMIN_KEY
          valueFrom:
            secretKeyRef:
              name: {{ .Values.apisix.admin.credentials.secretName }}
              key: admin
        - name: APISIX_VIEWER_KEY
          valueFrom:
            secretKeyRef:
              name: {{ .Values.apisix.admin.credentials.secretName }}
              key: viewer
      {{- end }}

      ports:
        - name: http
          containerPort: {{ .Values.service.http.containerPort }}
          protocol: TCP
        {{- range .Values.service.http.additionalContainerPorts }}
        - name: http-{{ .port | toString }}
          containerPort: {{ .port }}
          protocol: TCP
        {{- end }}     
        - name: tls
          containerPort: {{ .Values.apisix.ssl.containerPort }}
          protocol: TCP
        {{- range .Values.apisix.ssl.additionalContainerPorts }}
        - name: tls-{{ .port | toString }}
          containerPort: {{ .port }}
          protocol: TCP
        {{- end }}     
        {{- if .Values.apisix.admin.enabled }}
        - name: admin
          containerPort: {{ .Values.apisix.admin.port }}
          protocol: TCP
        {{- end }}
        {{- if .Values.apisix.prometheus.enabled }}
        - name: prometheus
          containerPort: {{ .Values.apisix.prometheus.containerPort }}
          protocol: TCP
        {{- end }}
        {{- if and .Values.service.stream.enabled (or (gt (len .Values.service.stream.tcp) 0) (gt (len .Values.service.stream.udp) 0)) }}
        {{- with .Values.service.stream }}
        {{- if (gt (len .tcp) 0) }}
        {{- range $index, $port := .tcp }}
        - name: proxy-tcp-{{ $index | toString }}
        {{- if kindIs "map" $port }}
          containerPort: {{ splitList ":" ($port.addr | toString) | last }}
        {{- else }}
          containerPort: {{ $port }}
        {{- end }}
          protocol: TCP
        {{- end }}
        {{- end }}
        {{- if (gt (len .udp) 0) }}
        {{- range $index, $port := .udp }}
        - name: proxy-udp-{{ $index | toString }}
          containerPort: {{ $port }}
          protocol: UDP
        {{- end }}
        {{- end }}
        {{- end }}
        {{- end }}

      {{- if ne .Values.apisix.deployment.role "control_plane" }}
      readinessProbe:
        failureThreshold: 6
        initialDelaySeconds: 10
        periodSeconds: 10
        successThreshold: 1
        tcpSocket:
          port: {{ .Values.service.http.containerPort }}
        timeoutSeconds: 1
      {{- end }}
      lifecycle:
        preStop:
          exec:
            command:
              - /bin/sh
              - -c
              - "sleep 30"
      volumeMounts:
      {{- if .Values.apisix.setIDFromPodUID }}
        - mountPath: /usr/local/apisix/conf/apisix.uid
          name: id
          subPath: apisix.uid
      {{- end }}
        - mountPath: /usr/local/apisix/conf/config.yaml
          name: apisix-config
          subPath: config.yaml
      {{- if and .Values.apisix.ssl.enabled .Values.apisix.ssl.existingCASecret }}
        - mountPath: /usr/local/apisix/conf/ssl/{{ .Values.apisix.ssl.certCAFilename }}
          name: ssl
          subPath: {{ .Values.apisix.ssl.certCAFilename }}
      {{- end }}

      {{- if and (eq .Values.apisix.deployment.role "control_plane") .Values.apisix.deployment.controlPlane.certsSecret }}
        - mountPath: /conf-server-ssl
          name: conf-server-ssl
      {{- end }}

      {{- if and (eq .Values.apisix.deployment.mode "decoupled") .Values.apisix.deployment.certs.mTLSCACertSecret }}
        - mountPath: /conf-ca-ssl
          name: conf-ca-ssl
      {{- end }}

      {{- if and (eq .Values.apisix.deployment.mode "decoupled") .Values.apisix.deployment.certs.certsSecret }}
        - mountPath: /conf-client-ssl
          name: conf-client-ssl
      {{- end }}

      {{- if .Values.etcd.auth.tls.enabled }}
        - mountPath: /etcd-ssl
          name: etcd-ssl
      {{- end }}
      {{- if .Values.apisix.customPlugins.enabled }}
      {{- range $plugin := .Values.apisix.customPlugins.plugins }}
      {{- range $mount := $plugin.configMap.mounts }}
      {{- if ne $plugin.configMap.name "" }}
        - mountPath: {{ $mount.path }}
          name: plugin-{{ $plugin.configMap.name }}
          subPath: {{ $mount.key }}
      {{- end }}
      {{- end }}
      {{- end }}
      {{- end }}
      {{- if .Values.apisix.luaModuleHook.enabled }}
      {{- range $mount := .Values.apisix.luaModuleHook.configMapRef.mounts }}
        - mountPath: {{ $mount.path }}
          name: lua-module-hook
          subPath: {{ $mount.key }}
      {{- end }}
      {{- end }}
      {{- if .Values.extraVolumeMounts }}
      {{- toYaml .Values.extraVolumeMounts | nindent 8 }}
      {{- end }}
      resources:
      {{- toYaml .Values.resources | nindent 8 }}
  {{- if .Values.hostNetwork }}
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  {{- end }}
  hostNetwork: {{ .Values.hostNetwork }}
  initContainers:
    {{- if .Values.etcd.enabled }}
    - name: wait-etcd
      image: {{ .Values.initContainer.image }}:{{ .Values.initContainer.tag }}
      {{- if .Values.etcd.fullnameOverride }}
      command: ['sh', '-c', "until nc -z {{ .Values.etcd.fullnameOverride }} {{ .Values.etcd.service.port }}; do echo waiting for etcd `date`; sleep 2; done;"]
      {{ else }}
      command: ['sh', '-c', "until nc -z {{ .Release.Name }}-etcd.{{ .Release.Namespace }}.svc.{{ .Values.etcd.clusterDomain }} {{ .Values.etcd.service.port }}; do echo waiting for etcd `date`; sleep 2; done;"]
      {{- end }}
    {{- end }}
    {{- if .Values.extraInitContainers }}
    {{- toYaml .Values.extraInitContainers | nindent 4 }}
    {{- end }}
  volumes:
    - configMap:
        name: {{ include "apisix.fullname" . }}
      name: apisix-config
    {{- if and .Values.apisix.ssl.enabled .Values.apisix.ssl.existingCASecret }}
    - secret:
        secretName: {{ .Values.apisix.ssl.existingCASecret | quote }}
      name: ssl
    {{- end }}
    {{- if .Values.etcd.auth.tls.enabled }}
    - secret:
        secretName: {{ .Values.etcd.auth.tls.existingSecret | quote }}
      name: etcd-ssl
    {{- end }}
    {{- if and (eq .Values.apisix.deployment.role "control_plane") .Values.apisix.deployment.controlPlane.certsSecret }}
    - secret:
        secretName: {{ .Values.apisix.deployment.controlPlane.certsSecret | quote }}
      name: conf-server-ssl
    {{- end }}

    {{- if and (eq .Values.apisix.deployment.mode "decoupled") .Values.apisix.deployment.certs.mTLSCACertSecret }}
    - secret:
        secretName: {{ .Values.apisix.deployment.certs.mTLSCACertSecret | quote }}
      name: conf-ca-ssl
    {{- end }}

    {{- if and (eq .Values.apisix.deployment.mode "decoupled") .Values.apisix.deployment.certs.certsSecret }}
    - secret:
        secretName: {{ .Values.apisix.deployment.certs.certsSecret | quote }}
      name: conf-client-ssl
    {{- end }}
    {{- if .Values.apisix.setIDFromPodUID }}
    - downwardAPI:
        items:
          - path: "apisix.uid"
            fieldRef:
              fieldPath: metadata.uid
      name: id
    {{- end }}
    {{- if .Values.apisix.customPlugins.enabled }}
    {{- range $plugin := .Values.apisix.customPlugins.plugins }}
    {{- if ne $plugin.configMap.name "" }}
    - name: plugin-{{ $plugin.configMap.name }}
      configMap:
        name: {{ $plugin.configMap.name }}
    {{- end }}
    {{- end }}
    {{- end }}
    {{- if .Values.apisix.luaModuleHook.enabled }}
    - name: lua-module-hook
      configMap:
        name: {{ .Values.apisix.luaModuleHook.configMapRef.name }}
    {{- end }}
    {{- if .Values.extraVolumes }}
    {{- toYaml .Values.extraVolumes | nindent 4 }}
    {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
