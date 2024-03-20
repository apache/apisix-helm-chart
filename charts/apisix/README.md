## Apache APISIX for Kubernetes

Apache APISIX is a dynamic, real-time, high-performance API gateway.

APISIX provides rich traffic management features such as load balancing, dynamic upstream, canary release, circuit breaking, authentication, observability, and more.

You can use Apache APISIX to handle traditional north-south traffic, as well as east-west traffic between services. It can also be used as a [k8s ingress controller](https://github.com/apache/apisix-ingress-controller/).

This chart bootstraps all the components needed to run Apache APISIX on a Kubernetes Cluster using [Helm](https://helm.sh).

## Prerequisites

* Kubernetes v1.14+
* Helm v3+

## Install

To install the chart with the release name `my-apisix`:

```sh
helm repo add apisix https://charts.apiseven.com
helm repo update

helm install [RELEASE_NAME] apisix/apisix --namespace ingress-apisix --create-namespace
```

## Uninstall

 To uninstall/delete a Helm release `my-apisix`:

 ```sh
helm delete [RELEASE_NAME] --namespace ingress-apisix
 ```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Parameters

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Set affinity for Apache APISIX deploy |
| apisix.admin.allow.ipList | list | `["127.0.0.1/24"]` | The client IP CIDR allowed to access Apache APISIX Admin API service. |
| apisix.admin.cors | bool | `true` | Admin API support CORS response headers |
| apisix.admin.credentials | object | `{"admin":"edd1c9f034335f136f87ad84b625c8f1","secretName":"","viewer":"4054f7cf07e344346cd3f287985e76a2"}` | Admin API credentials |
| apisix.admin.credentials.admin | string | `"edd1c9f034335f136f87ad84b625c8f1"` | Apache APISIX admin API admin role credentials |
| apisix.admin.credentials.secretName | string | `""` | The APISIX Helm chart supports storing user credentials in a secret. The secret needs to contain two keys, admin and viewer, with their respective values set. |
| apisix.admin.credentials.viewer | string | `"4054f7cf07e344346cd3f287985e76a2"` | Apache APISIX admin API viewer role credentials |
| apisix.admin.enabled | bool | `true` | Enable Admin API |
| apisix.admin.externalIPs | list | `[]` | IPs for which nodes in the cluster will also accept traffic for the servic |
| apisix.admin.ingress | object | `{"annotations":{},"enabled":false,"hosts":[{"host":"apisix-admin.local","paths":["/apisix"]}],"tls":[]}` | Using ingress access Apache APISIX admin service |
| apisix.admin.ingress.annotations | object | `{}` | Ingress annotations |
| apisix.admin.ip | string | `"0.0.0.0"` | which ip to listen on for Apache APISIX admin API. Set to `"[::]"` when on IPv6 single stack |
| apisix.admin.port | int | `9180` | which port to use for Apache APISIX admin API |
| apisix.admin.servicePort | int | `9180` | Service port to use for Apache APISIX admin API |
| apisix.admin.type | string | `"ClusterIP"` | admin service type |
| apisix.customPlugins | object | `{"enabled":false,"luaPath":"/opts/custom_plugins/?.lua","plugins":[{"attrs":{},"configMap":{"mounts":[{"key":"the-file-name","path":"mount-path"}],"name":"configmap-name"},"name":"plugin-name"}]}` | customPlugins allows you to mount your own HTTP plugins. |
| apisix.customPlugins.enabled | bool | `false` | Whether to configure some custom plugins |
| apisix.customPlugins.luaPath | string | `"/opts/custom_plugins/?.lua"` | the lua_path that tells APISIX where it can find plugins, note the last ';' is required. |
| apisix.customPlugins.plugins[0] | object | `{"attrs":{},"configMap":{"mounts":[{"key":"the-file-name","path":"mount-path"}],"name":"configmap-name"},"name":"plugin-name"}` | plugin name. |
| apisix.customPlugins.plugins[0].attrs | object | `{}` | plugin attrs |
| apisix.customPlugins.plugins[0].configMap | object | `{"mounts":[{"key":"the-file-name","path":"mount-path"}],"name":"configmap-name"}` | plugin codes can be saved inside configmap object. |
| apisix.customPlugins.plugins[0].configMap.mounts | list | `[{"key":"the-file-name","path":"mount-path"}]` | since keys in configmap is flat, mountPath allows to define the mount path, so that plugin codes can be mounted hierarchically. |
| apisix.customPlugins.plugins[0].configMap.name | string | `"configmap-name"` | name of configmap. |
| apisix.deployment.mode | string | `"traditional"` | Apache APISIX deployment mode Optional: traditional, decoupled, standalone  ref: https://apisix.apache.org/docs/apisix/deployment-modes/ |
| apisix.deployment.role | string | `"traditional"` | Deployment role Optional: traditional, data_plane, control_plane  ref: https://apisix.apache.org/docs/apisix/deployment-modes/ |
| apisix.discovery.enabled | bool | `false` | Enable or disable Apache APISIX integration service discovery |
| apisix.discovery.registry | object | `{}` | Registry is the same to the one in APISIX [config-default.yaml](https://github.com/apache/apisix/blob/master/conf/config-default.yaml#L281), and refer to such file for more setting details. also refer to [this documentation for integration service discovery](https://apisix.apache.org/docs/apisix/discovery) |
| apisix.dns.resolvers[0] | string | `"127.0.0.1"` |  |
| apisix.dns.resolvers[1] | string | `"172.20.0.10"` |  |
| apisix.dns.resolvers[2] | string | `"114.114.114.114"` |  |
| apisix.dns.resolvers[3] | string | `"223.5.5.5"` |  |
| apisix.dns.resolvers[4] | string | `"1.1.1.1"` |  |
| apisix.dns.resolvers[5] | string | `"8.8.8.8"` |  |
| apisix.dns.timeout | int | `5` |  |
| apisix.dns.validity | int | `30` |  |
| apisix.enableIPv6 | bool | `true` | Enable nginx IPv6 resolver |
| apisix.enableServerTokens | bool | `true` | Whether the APISIX version number should be shown in Server header |
| apisix.extPlugin.cmd | list | `["/path/to/apisix-plugin-runner/runner","run"]` | the command and its arguements to run as a subprocess |
| apisix.extPlugin.enabled | bool | `false` | Enable External Plugins. See [external plugin](https://apisix.apache.org/docs/apisix/next/external-plugin/) |
| apisix.fullCustomConfig.config | object | `{}` | If apisix.fullCustomConfig.enabled is true, full customized config.yaml. Please note that other settings about APISIX config will be ignored |
| apisix.fullCustomConfig.enabled | bool | `false` | Enable full customized config.yaml |
| apisix.luaModuleHook | object | `{"configMapRef":{"mounts":[{"key":"","path":""}],"name":""},"enabled":false,"hookPoint":"","luaPath":""}` | Whether to add a custom lua module |
| apisix.luaModuleHook.configMapRef | object | `{"mounts":[{"key":"","path":""}],"name":""}` | configmap that stores the codes |
| apisix.luaModuleHook.configMapRef.mounts[0] | object | `{"key":"","path":""}` | Name of the ConfigMap key, for setting the mapping relationship between ConfigMap key and the lua module code path. |
| apisix.luaModuleHook.configMapRef.mounts[0].path | string | `""` | Filepath of the plugin code, for setting the mapping relationship between ConfigMap key and the lua module code path. |
| apisix.luaModuleHook.configMapRef.name | string | `""` | Name of the ConfigMap where the lua module codes store |
| apisix.luaModuleHook.hookPoint | string | `""` | the hook module which will be used to inject third party code into APISIX use the lua require style like: "module.say_hello" |
| apisix.luaModuleHook.luaPath | string | `""` | extend lua_package_path to load third party code |
| apisix.nginx.configurationSnippet | object | `{"httpAdmin":"","httpEnd":"","httpSrv":"","httpStart":"","main":"","stream":""}` | Custom configuration snippet. |
| apisix.nginx.customLuaSharedDicts | list | `[]` | Add custom [lua_shared_dict](https://github.com/openresty/lua-nginx-module#toc88) settings, click [here](https://github.com/apache/apisix-helm-chart/blob/master/charts/apisix/values.yaml#L27-L30) to learn the format of a shared dict |
| apisix.nginx.enableCPUAffinity | bool | `true` |  |
| apisix.nginx.envs | list | `[]` |  |
| apisix.nginx.keepaliveTimeout | string | `"60s"` | Timeout during which a keep-alive client connection will stay open on the server side. |
| apisix.nginx.logs.accessLog | string | `"/dev/stdout"` | Access log path |
| apisix.nginx.logs.accessLogFormat | string | `"$remote_addr - $remote_user [$time_local] $http_host \\\"$request\\\" $status $body_bytes_sent $request_time \\\"$http_referer\\\" \\\"$http_user_agent\\\" $upstream_addr $upstream_status $upstream_response_time \\\"$upstream_scheme://$upstream_host$upstream_uri\\\""` | Access log format |
| apisix.nginx.logs.accessLogFormatEscape | string | `"default"` | Allows setting json or default characters escaping in variables |
| apisix.nginx.logs.enableAccessLog | bool | `true` | Enable access log or not, default true |
| apisix.nginx.logs.errorLog | string | `"/dev/stderr"` | Error log path |
| apisix.nginx.logs.errorLogLevel | string | `"warn"` | Error log level |
| apisix.nginx.workerConnections | string | `"10620"` |  |
| apisix.nginx.workerProcesses | string | `"auto"` |  |
| apisix.nginx.workerRlimitNofile | string | `"20480"` |  |
| apisix.pluginAttrs | object | `{}` | Set APISIX plugin attributes, see [config-default.yaml](https://github.com/apache/apisix/blob/master/conf/config-default.yaml#L376) for more details |
| apisix.plugins | list | `[]` | Customize the list of APISIX plugins to enable. By default, APISIX's default plugins are automatically used. See [config-default.yaml](https://github.com/apache/apisix/blob/master/conf/config-default.yaml) |
| apisix.prometheus.containerPort | int | `9091` | container port where the metrics are exposed |
| apisix.prometheus.enabled | bool | `false` |  |
| apisix.prometheus.metricPrefix | string | `"apisix_"` | prefix of the metrics |
| apisix.prometheus.path | string | `"/apisix/prometheus/metrics"` | path of the metrics endpoint |
| apisix.router.http | string | `"radixtree_host_uri"` | Defines how apisix handles routing: - radixtree_uri: match route by uri(base on radixtree) - radixtree_host_uri: match route by host + uri(base on radixtree) - radixtree_uri_with_parameter: match route by uri with parameters |
| apisix.setIDFromPodUID | bool | `false` | Use Pod metadata.uid as the APISIX id. |
| apisix.ssl.additionalContainerPorts | list | `[]` | Support multiple https ports, See [Configuration](https://github.com/apache/apisix/blob/0bc65ea9acd726f79f80ae0abd8f50b7eb172e3d/conf/config-default.yaml#L99) |
| apisix.ssl.certCAFilename | string | `""` | Filename be used in the apisix.ssl.existingCASecret |
| apisix.ssl.containerPort | int | `9443` |  |
| apisix.ssl.enabled | bool | `false` |  |
| apisix.ssl.existingCASecret | string | `""` | Specifies the name of Secret contains trusted CA certificates in the PEM format used to verify the certificate when APISIX needs to do SSL/TLS handshaking with external services (e.g. etcd) |
| apisix.ssl.fallbackSNI | string | `""` | Define SNI to fallback if none is presented by client |
| apisix.ssl.http2.enabled | bool | `true` |  |
| apisix.ssl.sslProtocols | string | `"TLSv1.2 TLSv1.3"` | TLS protocols allowed to use. |
| apisix.stream_plugins | list | `[]` | Customize the list of APISIX stream_plugins to enable. By default, APISIX's default stream_plugins are automatically used. See [config-default.yaml](https://github.com/apache/apisix/blob/master/conf/config-default.yaml) |
| apisix.vault.enabled | bool | `false` | Enable or disable the vault integration |
| apisix.vault.host | string | `""` | The host address where the vault server is running. |
| apisix.vault.prefix | string | `""` | Prefix allows you to better enforcement of policies. |
| apisix.vault.timeout | int | `10` | HTTP timeout for each request. |
| apisix.vault.token | string | `""` | The generated token from vault instance that can grant access to read data from the vault. |
| apisix.wasm.enabled | bool | `false` | Enable Wasm Plugins. See [wasm plugin](https://apisix.apache.org/docs/apisix/next/wasm/) |
| apisix.wasm.plugins | list | `[]` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| autoscaling.version | string | `"v2"` | HPA version, the value is "v2" or "v2beta1", default "v2" |
| dashboard.config.conf.etcd.endpoints | list | `["apisix-etcd:2379"]` | Supports defining multiple etcd host addresses for an etcd cluster |
| dashboard.config.conf.etcd.password | string | `nil` | Specifies etcd basic auth password if enable etcd auth |
| dashboard.config.conf.etcd.prefix | string | `"/apisix"` | apisix configurations prefix |
| dashboard.config.conf.etcd.username | string | `nil` | Specifies etcd basic auth username if enable etcd auth |
| dashboard.enabled | bool | `false` |  |
| etcd | object | `{"auth":{"rbac":{"create":false,"rootPassword":""},"tls":{"certFilename":"","certKeyFilename":"","enabled":false,"existingSecret":"","sni":"","verify":true}},"enabled":true,"prefix":"/apisix","replicaCount":3,"service":{"port":2379},"timeout":30}` | etcd configuration use the FQDN address or the IP of the etcd |
| etcd.auth | object | `{"rbac":{"create":false,"rootPassword":""},"tls":{"certFilename":"","certKeyFilename":"","enabled":false,"existingSecret":"","sni":"","verify":true}}` | if etcd.enabled is true, set more values of bitnami/etcd helm chart |
| etcd.auth.rbac.create | bool | `false` | No authentication by default. Switch to enable RBAC authentication |
| etcd.auth.rbac.rootPassword | string | `""` | root password for etcd. Requires etcd.auth.rbac.create to be true. |
| etcd.auth.tls.certFilename | string | `""` | etcd client cert filename using in etcd.auth.tls.existingSecret |
| etcd.auth.tls.certKeyFilename | string | `""` | etcd client cert key filename using in etcd.auth.tls.existingSecret |
| etcd.auth.tls.enabled | bool | `false` | enable etcd client certificate |
| etcd.auth.tls.existingSecret | string | `""` | name of the secret contains etcd client cert |
| etcd.auth.tls.sni | string | `""` | specify the TLS Server Name Indication extension, the ETCD endpoint hostname will be used when this setting is unset. |
| etcd.auth.tls.verify | bool | `true` | whether to verify the etcd endpoint certificate when setup a TLS connection to etcd |
| etcd.enabled | bool | `true` | install etcd(v3) by default, set false if do not want to install etcd(v3) together |
| etcd.prefix | string | `"/apisix"` | apisix configurations prefix |
| etcd.timeout | int | `30` | Set the timeout value in seconds for subsequent socket operations from apisix to etcd cluster |
| externalEtcd | object | `{"existingSecret":"","host":["http://etcd.host:2379"],"password":"","secretPasswordKey":"etcd-root-password","user":"root"}` | external etcd configuration. If etcd.enabled is false, these configuration will be used. |
| externalEtcd.existingSecret | string | `""` | if externalEtcd.existingSecret is the name of secret containing the external etcd password |
| externalEtcd.host | list | `["http://etcd.host:2379"]` | if etcd.enabled is false, use external etcd, support multiple address, if your etcd cluster enables TLS, please use https scheme, e.g. https://127.0.0.1:2379. |
| externalEtcd.password | string | `""` | if etcd.enabled is false and externalEtcd.existingSecret is empty, externalEtcd.password is the passsword for external etcd. |
| externalEtcd.secretPasswordKey | string | `"etcd-root-password"` | externalEtcd.secretPasswordKey Key inside the secret containing the external etcd password |
| externalEtcd.user | string | `"root"` | if etcd.enabled is false, user for external etcd. Set empty to disable authentication |
| extraContainers | list | `[]` | Additional `containers`, See [Kubernetes containers](https://kubernetes.io/docs/concepts/containers/) for the detail. |
| extraDeploy | list | `[]` | Additional Kubernetes resources to deploy with the release. |
| extraEnvVars | list | `[]` | extraEnvVars An array to add extra env vars e.g: extraEnvVars:   - name: FOO     value: "bar"   - name: FOO2     valueFrom:       secretKeyRef:         name: SECRET_NAME         key: KEY |
| extraInitContainers | list | `[]` | Additional `initContainers`, See [Kubernetes initContainers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) for the detail. |
| extraVolumeMounts | list | `[]` | Additional `volume`, See [Kubernetes Volumes](https://kubernetes.io/docs/concepts/storage/volumes/) for the detail. |
| extraVolumes | list | `[]` | Additional `volume`, See [Kubernetes Volumes](https://kubernetes.io/docs/concepts/storage/volumes/) for the detail. |
| fullnameOverride | string | `""` |  |
| global.imagePullSecrets | list | `[]` | Global Docker registry secret names as an array |
| hostNetwork | bool | `false` |  |
| image.pullPolicy | string | `"IfNotPresent"` | Apache APISIX image pull policy |
| image.repository | string | `"apache/apisix"` | Apache APISIX image repository |
| image.tag | string | `"3.8.0-debian"` | Apache APISIX image tag Overrides the image tag whose default is the chart appVersion. |
| ingress | object | `{"annotations":{},"enabled":false,"hosts":[{"host":"apisix.local","paths":[]}],"servicePort":null,"tls":[]}` | Using ingress access Apache APISIX service |
| ingress-controller | object | `{"config":{"apisix":{"adminAPIVersion":"v3"}},"enabled":false}` | Ingress controller configuration |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.servicePort | number | `nil` | Service port to send traffic. Defaults to `service.http.servicePort`. |
| initContainer.image | string | `"busybox"` | Init container image |
| initContainer.tag | float | `1.28` | Init container tag |
| metrics | object | `{"serviceMonitor":{"annotations":{},"enabled":false,"interval":"15s","labels":{},"name":"","namespace":""}}` | Observability configuration. |
| metrics.serviceMonitor.annotations | object | `{}` | @param serviceMonitor.annotations ServiceMonitor annotations |
| metrics.serviceMonitor.enabled | bool | `false` | Enable or disable Apache APISIX serviceMonitor |
| metrics.serviceMonitor.interval | string | `"15s"` | interval at which metrics should be scraped |
| metrics.serviceMonitor.labels | object | `{}` | @param serviceMonitor.labels ServiceMonitor extra labels |
| metrics.serviceMonitor.name | string | `""` | name of the serviceMonitor, by default, it is the same as the apisix fullname |
| metrics.serviceMonitor.namespace | string | `""` | namespace where the serviceMonitor is deployed, by default, it is the same as the namespace of the apisix |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` | Node labels for Apache APISIX pod assignment |
| podAnnotations | object | `{}` | Annotations to add to each pod |
| podDisruptionBudget | object | `{"enabled":false,"maxUnavailable":1,"minAvailable":"90%"}` | See https://kubernetes.io/docs/tasks/run-application/configure-pdb/ for more details |
| podDisruptionBudget.enabled | bool | `false` | Enable or disable podDisruptionBudget |
| podDisruptionBudget.maxUnavailable | int | `1` | Set the maxUnavailable of podDisruptionBudget |
| podDisruptionBudget.minAvailable | string | `"90%"` | Set the `minAvailable` of podDisruptionBudget. You can specify only one of `maxUnavailable` and `minAvailable` in a single PodDisruptionBudget. See [Specifying a Disruption Budget for your Application](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#specifying-a-poddisruptionbudget) for more details |
| podSecurityContext | object | `{}` | Set the securityContext for Apache APISIX pods |
| priorityClassName | string | `""` | Set [priorityClassName](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#pod-priority) for Apache APISIX pods |
| rbac.create | bool | `false` |  |
| replicaCount | int | `1` | if useDaemonSet is true or autoscaling.enabled is true, replicaCount not become effective |
| resources | object | `{}` | Set pod resource requests & limits |
| securityContext | object | `{}` | Set the securityContext for Apache APISIX container |
| service.externalIPs | list | `[]` |  |
| service.externalTrafficPolicy | string | `"Cluster"` |  |
| service.http | object | `{"additionalContainerPorts":[],"containerPort":9080,"enabled":true,"servicePort":80}` | Apache APISIX service settings for http |
| service.http.additionalContainerPorts | list | `[]` | Support multiple http ports, See [Configuration](https://github.com/apache/apisix/blob/0bc65ea9acd726f79f80ae0abd8f50b7eb172e3d/conf/config-default.yaml#L24) |
| service.labelsOverride | object | `{}` | Override default labels assigned to Apache APISIX gateway resources |
| service.stream | object | `{"enabled":false,"tcp":[],"udp":[]}` | Apache APISIX service settings for stream. L4 proxy (TCP/UDP) |
| service.tls | object | `{"servicePort":443}` | Apache APISIX service settings for tls |
| service.type | string | `"NodePort"` | Apache APISIX service type for user access itself |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `false` |  |
| serviceAccount.name | string | `""` |  |
| timezone | string | `""` | timezone is the timezone where apisix uses. For example: "UTC" or "Asia/Shanghai" This value will be set on apisix container's environment variable TZ. You may need to set the timezone to be consistent with your local time zone, otherwise the apisix's logs may used to retrieve event maybe in wrong timezone. |
| tolerations | list | `[]` | List of node taints to tolerate |
| updateStrategy | object | `{}` |  |
| useDaemonSet | bool | `false` | set false to use `Deployment`, set true to use `DaemonSet` |
