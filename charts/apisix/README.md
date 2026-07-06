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
helm repo add apisix https://apache.github.io/apisix-helm-chart
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
| apisix.admin.credentials | object | `{"admin":"edd1c9f034335f136f87ad84b625c8f1","secretAdminKey":"","secretName":"","secretViewerKey":"","viewer":"4054f7cf07e344346cd3f287985e76a2"}` | Admin API credentials |
| apisix.admin.credentials.admin | string | `"edd1c9f034335f136f87ad84b625c8f1"` | Apache APISIX admin API admin role credentials |
| apisix.admin.credentials.secretAdminKey | string | `""` | Name of the admin role key in the secret, overrides the default key name "admin" |
| apisix.admin.credentials.secretName | string | `""` | The APISIX Helm chart supports storing user credentials in a secret. The secret needs to contain two keys, admin and viewer, with their respective values set. |
| apisix.admin.credentials.secretViewerKey | string | `""` | Name of the viewer role key in the secret, overrides the default key name "viewer" |
| apisix.admin.credentials.viewer | string | `"4054f7cf07e344346cd3f287985e76a2"` | Apache APISIX admin API viewer role credentials |
| apisix.admin.enable_admin_ui | bool | `true` | Enable Embedded Admin UI |
| apisix.admin.enabled | bool | `true` | Enable Admin API |
| apisix.admin.externalIPs | list | `[]` | IPs for which nodes in the cluster will also accept traffic for the servic |
| apisix.admin.ingress | object | `{"annotations":{},"enabled":false,"hosts":[{"host":"apisix-admin.local","paths":["/apisix"]}],"tls":[]}` | Using ingress access Apache APISIX admin service |
| apisix.admin.ingress.annotations | object | `{}` | Ingress annotations |
| apisix.admin.ingress.enabled | bool | `false` | Enable an Ingress resource in front of the Admin API service |
| apisix.admin.ingress.hosts | list | `[{"host":"apisix-admin.local","paths":["/apisix"]}]` | Ingress host and path rules |
| apisix.admin.ingress.tls | list | `[]` | Ingress TLS settings |
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
| apisix.deleteURITailSlash | bool | `false` | Delete the '/' at the end of the URI |
| apisix.deployment.mode | string | `"traditional"` | Apache APISIX deployment mode Optional: traditional, decoupled, standalone  ref: https://apisix.apache.org/docs/apisix/deployment-modes/ |
| apisix.deployment.role | string | `"traditional"` | Deployment role Optional: traditional, data_plane, control_plane  ref: https://apisix.apache.org/docs/apisix/deployment-modes/ |
| apisix.deployment.role_traditional.config_provider | string | `"etcd"` | Config provider for the traditional role. enum: etcd, yaml |
| apisix.deployment.standalone | object | `{"config":"routes:\n-\n  uri: /hi\n  upstream:\n    nodes:\n      \"127.0.0.1:1980\": 1\n    type: roundrobin\n","existingConfigMap":""}` | Standalone rules configuration  ref: https://apisix.apache.org/docs/apisix/deployment-modes/#standalone |
| apisix.deployment.standalone.config | string | `"routes:\n-\n  uri: /hi\n  upstream:\n    nodes:\n      \"127.0.0.1:1980\": 1\n    type: roundrobin\n"` | Rules which are set to the default apisix.yaml configmap. If apisix.delpoyment.standalone.existingConfigMap is empty, these are used. |
| apisix.deployment.standalone.existingConfigMap | string | `""` | Specifies the name of the ConfigMap that contains the rule configurations. The configuration must be set to the key named `apisix.yaml` in the configmap. |
| apisix.discovery.enabled | bool | `false` | Enable or disable Apache APISIX integration service discovery |
| apisix.discovery.registry | object | `{}` | Service discovery registry. Refer to [configuration under discovery](https://github.com/apache/apisix/blob/master/conf/config.yaml.example#L307) for example. Also see [example of using external service discovery](https://apisix.apache.org/docs/ingress-controller/1.8.0/tutorials/external-service-discovery/). |
| apisix.dns.enableResolvSearchOpt | bool | `true` | Honor the `search` option in `/etc/resolv.conf` when resolving domain names |
| apisix.dns.resolvers | list | `[]` | Nameservers used by APISIX to resolve upstream domain names. When empty (default), nameservers are read from `/etc/resolv.conf`, which is usually what you want inside Kubernetes |
| apisix.dns.timeout | int | `5` | DNS resolver timeout in seconds |
| apisix.dns.validity | int | `30` | Override the TTL in seconds of valid DNS records |
| apisix.enableHTTP2 | bool | `true` | Enable HTTP/2 on the HTTP listeners |
| apisix.enableIPv6 | bool | `true` | Enable nginx IPv6 resolver |
| apisix.enableServerTokens | bool | `true` | Whether the APISIX version number should be shown in Server header |
| apisix.extPlugin.cmd | list | `["/path/to/apisix-plugin-runner/runner","run"]` | the command and its arguements to run as a subprocess |
| apisix.extPlugin.enabled | bool | `false` | Enable External Plugins. See [external plugin](https://apisix.apache.org/docs/apisix/next/external-plugin/) |
| apisix.fullCustomConfig.config | object | `{}` | If apisix.fullCustomConfig.enabled is true, full customized config.yaml. Please note that other settings about APISIX config will be ignored |
| apisix.fullCustomConfig.enabled | bool | `false` | Enable full customized config.yaml |
| apisix.graphql.maxSize | int | `1048576` | The maximum size in bytes of GraphQL queries APISIX parses when matching routes by GraphQL attributes (default 1MiB) |
| apisix.lru | object | `{"secret":{"count":512,"neg_count":512,"neg_ttl":60,"ttl":300}}` | fine tune the parameters of LRU cache for some features like secret |
| apisix.lru.secret.count | int | `512` | Maximum number of cached secret values |
| apisix.lru.secret.neg_count | int | `512` | Maximum number of cached negative (failed lookup) results |
| apisix.lru.secret.neg_ttl | int | `60` | TTL in seconds for cached negative (failed lookup) results |
| apisix.lru.secret.ttl | int | `300` | TTL in seconds for cached secret values |
| apisix.luaModuleHook | object | `{"configMapRef":{"mounts":[{"key":"","path":""}],"name":""},"enabled":false,"hookPoint":"","luaPath":""}` | Whether to add a custom lua module |
| apisix.luaModuleHook.configMapRef | object | `{"mounts":[{"key":"","path":""}],"name":""}` | configmap that stores the codes |
| apisix.luaModuleHook.configMapRef.mounts[0] | object | `{"key":"","path":""}` | Name of the ConfigMap key, for setting the mapping relationship between ConfigMap key and the lua module code path. |
| apisix.luaModuleHook.configMapRef.mounts[0].path | string | `""` | Filepath of the plugin code, for setting the mapping relationship between ConfigMap key and the lua module code path. |
| apisix.luaModuleHook.configMapRef.name | string | `""` | Name of the ConfigMap where the lua module codes store |
| apisix.luaModuleHook.enabled | bool | `false` | Enable loading a custom lua module hook |
| apisix.luaModuleHook.hookPoint | string | `""` | the hook module which will be used to inject third party code into APISIX use the lua require style like: "module.say_hello" |
| apisix.luaModuleHook.luaPath | string | `""` | extend lua_package_path to load third party code |
| apisix.nginx.configurationSnippet | object | `{"httpAdmin":"","httpEnd":"","httpSrv":"","httpStart":"","main":"","stream":""}` | Custom nginx configuration snippets injected into the generated nginx.conf. As arbitrary configuration can be added here, it is your responsibility to make sure the snippets don't conflict with the configuration generated by APISIX. |
| apisix.nginx.configurationSnippet.httpAdmin | string | `""` | Snippet added to the nginx `server` block that serves the Admin API |
| apisix.nginx.configurationSnippet.httpEnd | string | `""` | Snippet added to the end of the nginx `http` block |
| apisix.nginx.configurationSnippet.httpSrv | string | `""` | Snippet added to the nginx `server` block that proxies regular traffic |
| apisix.nginx.configurationSnippet.httpStart | string | `""` | Snippet added to the beginning of the nginx `http` block |
| apisix.nginx.configurationSnippet.main | string | `""` | Snippet added to the nginx `main` (top-level) block |
| apisix.nginx.configurationSnippet.stream | string | `""` | Snippet added to the nginx `stream` block |
| apisix.nginx.customLuaSharedDicts | list | `[]` | Add custom [lua_shared_dict](https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#lua_shared_dict) settings, click [here](https://github.com/apache/apisix-helm-chart/blob/master/charts/apisix/values.yaml#L27-L30) to learn the format of a shared dict |
| apisix.nginx.enableCPUAffinity | bool | `true` | Bind nginx worker processes to CPUs |
| apisix.nginx.envs | list | `[]` | List of environment variable names allowed to be accessed within nginx (rendered as nginx `env` directives) |
| apisix.nginx.http | object | `{"charset":"utf-8","clientBodyTimeout":"60s","clientHeaderTimeout":"60s","clientMaxBodySize":0,"proxySslServerName":true,"realIpFrom":["127.0.0.1","unix:"],"realIpHeader":"X-Real-IP","realIpRecursive":"off","sendTimeout":"10s","underscoresInHeaders":"on","upstream":{"keepalive":320,"keepaliveRequests":1000,"keepaliveTimeout":"60s"},"variablesHashMaxSize":2048}` | Nginx HTTP subsystem configurations |
| apisix.nginx.http.charset | string | `"utf-8"` | The charset added to the "Content-Type" response header field, see [charset](http://nginx.org/en/docs/http/ngx_http_charset_module.html#charset) |
| apisix.nginx.http.clientBodyTimeout | string | `"60s"` | timeout for reading client request body, then 408 (Request Time-out) error is returned to the client |
| apisix.nginx.http.clientHeaderTimeout | string | `"60s"` | timeout for reading client request header, then 408 (Request Time-out) error is returned to the client |
| apisix.nginx.http.clientMaxBodySize | int | `0` | The maximum allowed size of the client request body. If exceeded, the 413 (Request Entity Too Large) error is returned to the client. Note that unlike Nginx, we don't limit the body size by default (0 means no limit). |
| apisix.nginx.http.proxySslServerName | bool | `true` | Enables or disables passing of the server name through TLS Server Name Indication extension (SNI, RFC 6066) when establishing a connection with the proxied HTTPS server |
| apisix.nginx.http.realIpFrom | list | `["127.0.0.1","unix:"]` | Trusted addresses from which the real IP header is honored, see [set_real_ip_from](http://nginx.org/en/docs/http/ngx_http_realip_module.html#set_real_ip_from) |
| apisix.nginx.http.realIpHeader | string | `"X-Real-IP"` | The request header used to determine the client's real IP address, see [real_ip_header](http://nginx.org/en/docs/http/ngx_http_realip_module.html#real_ip_header) |
| apisix.nginx.http.realIpRecursive | string | `"off"` | Whether to search for the real IP recursively when the header set in apisix.nginx.http.realIpHeader contains multiple addresses, see [real_ip_recursive](http://nginx.org/en/docs/http/ngx_http_realip_module.html#real_ip_recursive) |
| apisix.nginx.http.sendTimeout | string | `"10s"` | timeout for transmitting a response to the client, then the connection is closed |
| apisix.nginx.http.underscoresInHeaders | string | `"on"` | Enable the use of underscores in client request header fields |
| apisix.nginx.http.upstream | object | `{"keepalive":320,"keepaliveRequests":1000,"keepaliveTimeout":"60s"}` | Keepalive settings for connections from APISIX to upstream servers |
| apisix.nginx.http.upstream.keepalive | int | `320` | Maximum number of idle keepalive connections to upstream servers that are preserved in the cache of each worker process. When this number is exceeded, the least recently used connections are closed |
| apisix.nginx.http.upstream.keepaliveRequests | int | `1000` | Maximum number of requests that can be served through one keepalive connection. After the maximum number of requests is made, the connection is closed |
| apisix.nginx.http.upstream.keepaliveTimeout | string | `"60s"` | Timeout during which an idle keepalive connection to an upstream server will stay open |
| apisix.nginx.http.variablesHashMaxSize | int | `2048` | The maximum size of the nginx variables hash table |
| apisix.nginx.keepaliveTimeout | string | `"60s"` | Timeout during which a keep-alive client connection will stay open on the server side. |
| apisix.nginx.logs.accessLog | string | `"/dev/stdout"` | Access log path |
| apisix.nginx.logs.accessLogFormat | string | `"$remote_addr - $remote_user [$time_local] $http_host \\\"$request\\\" $status $body_bytes_sent $request_time \\\"$http_referer\\\" \\\"$http_user_agent\\\" $upstream_addr $upstream_status $upstream_response_time \\\"$upstream_scheme://$upstream_host$upstream_uri\\\""` | Access log format |
| apisix.nginx.logs.accessLogFormatEscape | string | `"default"` | Allows setting json or default characters escaping in variables |
| apisix.nginx.logs.enableAccessLog | bool | `true` | Enable access log or not, default true |
| apisix.nginx.logs.errorLog | string | `"/dev/stderr"` | Error log path |
| apisix.nginx.logs.errorLogLevel | string | `"warn"` | Error log level |
| apisix.nginx.logs.stream | object | `{"accessLog":"logs/access_stream.log","accessLogFormat":"$remote_addr [$time_local] $protocol $status $bytes_sent $bytes_received $session_time","accessLogFormatEscape":"default","enableAccessLog":false}` | Stream (L4 proxy) access log configuration |
| apisix.nginx.logs.stream.accessLog | string | `"logs/access_stream.log"` | Stream access log path |
| apisix.nginx.logs.stream.accessLogFormat | string | `"$remote_addr [$time_local] $protocol $status $bytes_sent $bytes_received $session_time"` | Stream access log format |
| apisix.nginx.logs.stream.accessLogFormatEscape | string | `"default"` | Allows setting json or default characters escaping in variables for stream |
| apisix.nginx.logs.stream.enableAccessLog | bool | `false` | Enable stream access log or not, default false |
| apisix.nginx.luaSharedDicts | list | `[]` | Override default [lua_shared_dict](https://github.com/apache/apisix/blob/master/conf/config.yaml.example#L250-L276) settings, click [here](https://github.com/apache/apisix-helm-chart/blob/master/charts/apisix/values.yaml#L27-L30) to learn the format of a shared dict |
| apisix.nginx.maxPendingTimers | int | `16384` | Maximum number of pending timers. Increase it if you see "too many pending timers" error |
| apisix.nginx.maxRunningTimers | int | `4096` | Maximum number of running timers. Increase it if you see "lua_max_running_timers are not enough" error |
| apisix.nginx.metaLuaSharedDicts | list | `[]` | Override default meta-level [lua_shared_dict](https://github.com/apache/apisix/blob/master/conf/config.yaml.example) settings, meta-level shared dicts are shared across both HTTP and stream subsystems. Since APISIX 3.16.0, `upstream-healthcheck` is a meta-level shared dict. click [here](https://github.com/apache/apisix-helm-chart/blob/master/charts/apisix/values.yaml#L27-L30) to learn the format of a shared dict |
| apisix.nginx.workerConnections | string | `"10620"` | The maximum number of connections that each worker process can open |
| apisix.nginx.workerProcesses | string | `"auto"` | The number of nginx worker processes. `auto` means the number of CPU cores |
| apisix.nginx.workerRlimitNofile | string | `"20480"` | The number of files a worker process can open, should be larger than apisix.nginx.workerConnections |
| apisix.nginx.workerShutdownTimeout | string | `"240s"` | Timeout for a graceful shutdown of worker processes |
| apisix.normalizeURILikeServlet | bool | `false` | The URI normalization in servlet is a little different from the RFC's. See https://github.com/jakartaee/servlet/blob/master/spec/src/main/asciidoc/servlet-spec-body.adoc#352-uri-path-canonicalization, which is used under Tomcat. Turn this option on if you want to be compatible with servlet when matching URI path. |
| apisix.pluginAttrs | object | `{}` | Set APISIX plugin attributes. By default, APISIX's [plugin_attr](https://github.com/apache/apisix/blob/master/apisix/cli/config.lua#L295) are automatically used. See [configuration example](https://github.com/apache/apisix/blob/master/conf/config.yaml.example#L591). |
| apisix.plugins | list | `[]` | Customize the list of APISIX plugins to enable. By default, APISIX's [default plugins](https://github.com/apache/apisix/blob/master/apisix/cli/config.lua#L196) are automatically used. |
| apisix.prometheus.containerPort | int | `9091` | container port where the metrics are exposed |
| apisix.prometheus.enabled | bool | `false` | Enable Prometheus metrics. ref: https://apisix.apache.org/docs/apisix/plugins/prometheus/ |
| apisix.prometheus.metricPrefix | string | `"apisix_"` | prefix of the metrics |
| apisix.prometheus.path | string | `"/apisix/prometheus/metrics"` | path of the metrics endpoint |
| apisix.proxyCache | object | `{"cacheTtl":"10s","zones":[{"cache_levels":"1:2","disk_path":"/tmp/disk_cache_one","disk_size":"1G","memory_size":"50m","name":"disk_cache_one"},{"memory_size":"50m","name":"memory_cache"}]}` | Proxy caching configuration used by the proxy-cache plugin. |
| apisix.proxyCache.cacheTtl | string | `"10s"` | The default caching time in disk if the upstream does not specify the cache time |
| apisix.proxyCache.zones | list | `[{"cache_levels":"1:2","disk_path":"/tmp/disk_cache_one","disk_size":"1G","memory_size":"50m","name":"disk_cache_one"},{"memory_size":"50m","name":"memory_cache"}]` | The parameters of a cache. The `memory_size` field stores the cache index for the disk strategy and the cache content for the memory strategy; `disk_size`, `disk_path` and `cache_levels` only apply to the disk strategy. |
| apisix.proxyProtocol | object | `{"enableTcpPP":false,"enableTcpPPToUpstream":false,"listenHttpNodePort":null,"listenHttpPort":null,"listenHttpsNodePort":null,"listenHttpsPort":null}` | PROXY Protocol configuration. |
| apisix.proxyProtocol.enableTcpPP | bool | `false` | Accept the PROXY Protocol on every service.stream.tcp port. |
| apisix.proxyProtocol.enableTcpPPToUpstream | bool | `false` | Send the PROXY Protocol to the upstream server on every service.stream.tcp port. |
| apisix.proxyProtocol.listenHttpNodePort | int | `nil` | The nodePort of the PROXY Protocol HTTP port, only used if service.type is NodePort. If not set, a random port will be assigned by Kubernetes. |
| apisix.proxyProtocol.listenHttpPort | int | `nil` | The HTTP port that accepts the PROXY Protocol. It differs from `service.http` ports and `apisix.admin` port: this port only accepts HTTP requests carrying the PROXY Protocol, while the other ports only accept plain HTTP requests. If you enable the PROXY Protocol, you must use this port to receive HTTP requests with it. When set, the port is also exposed on the gateway Service. |
| apisix.proxyProtocol.listenHttpsNodePort | int | `nil` | The nodePort of the PROXY Protocol HTTPS port, only used if service.type is NodePort. If not set, a random port will be assigned by Kubernetes. |
| apisix.proxyProtocol.listenHttpsPort | int | `nil` | The HTTPS port that accepts the PROXY Protocol. When set, the port is also exposed on the gateway Service. |
| apisix.router.http | string | `"radixtree_host_uri"` | Defines how apisix handles routing: - radixtree_uri: match route by uri(base on radixtree) - radixtree_host_uri: match route by host + uri(base on radixtree) - radixtree_uri_with_parameter: match route by uri with parameters |
| apisix.setIDFromPodUID | bool | `false` | Use Pod metadata.uid as the APISIX id. |
| apisix.showUpstreamStatusInResponseHeader | bool | `false` | When true, the upstream status is always written to the `X-APISIX-Upstream-Status` response header; when false, it is written only for 5xx responses |
| apisix.ssl.additionalContainerPorts | list | `[]` | Support multiple https ports, See [Configuration](https://github.com/apache/apisix/blob/0bc65ea9acd726f79f80ae0abd8f50b7eb172e3d/conf/config-default.yaml#L99) |
| apisix.ssl.certCAFilename | string | `""` | Filename be used in the apisix.ssl.existingCASecret |
| apisix.ssl.containerPort | int | `9443` | Container port APISIX listens on for HTTPS traffic |
| apisix.ssl.enableHTTP3 | bool | `false` | Enable HTTP/3 (QUIC) on the HTTPS listeners |
| apisix.ssl.enabled | bool | `false` | Enable HTTPS listeners |
| apisix.ssl.existingCASecret | string | `""` | Specifies the name of Secret contains trusted CA certificates in the PEM format used to verify the certificate when APISIX needs to do SSL/TLS handshaking with external services (e.g. etcd) |
| apisix.ssl.fallbackSNI | string | `""` | Define SNI to fallback if none is presented by client |
| apisix.ssl.sslCiphers | string | `"ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA"` | TLS ciphers allowed to use. |
| apisix.ssl.sslProtocols | string | `"TLSv1.2 TLSv1.3"` | TLS protocols allowed to use. |
| apisix.ssl.sslSessionTickets | bool | `false` | Enable or disable TLS session tickets. Disabled by default because session tickets defeat Perfect Forward Secrecy (see https://github.com/mozilla/server-side-tls/issues/135) |
| apisix.status.ip | string | `"0.0.0.0"` | The IP address on which the status endpoint (`/status`, `/status/ready`) listens |
| apisix.status.port | int | `7085` | The port on which the status endpoint listens |
| apisix.stream_plugins | list | `[]` | Customize the list of APISIX stream_plugins to enable. By default, APISIX's [default stream_plugins](https://github.com/apache/apisix/blob/master/apisix/cli/config.lua#L294) are automatically used. |
| apisix.tracing | bool | `false` | Enable comprehensive request lifecycle tracing (SSL/SNI, rewrite, access, header_filter, body_filter, and log). When disabled, OpenTelemetry collects only a single span per request. |
| apisix.trustedAddresses | list | `["127.0.0.1"]` | When configured, APISIX will trust the `X-Forwarded-*` Headers passed in requests from the IP/CIDR in the list. |
| apisix.vault.enabled | bool | `false` | Enable or disable the vault integration |
| apisix.vault.host | string | `""` | The host address where the vault server is running. |
| apisix.vault.prefix | string | `""` | Prefix allows you to better enforcement of policies. |
| apisix.vault.timeout | int | `10` | HTTP timeout for each request. |
| apisix.vault.token | string | `""` | The generated token from vault instance that can grant access to read data from the vault. |
| apisix.wasm.enabled | bool | `false` | Enable Wasm Plugins. See [wasm plugin](https://apisix.apache.org/docs/apisix/next/wasm/) |
| apisix.wasm.plugins | list | `[]` | List of Wasm plugins, each item with `name`, `priority` and `file` (path or URL of the wasm binary) |
| autoscaling.enabled | bool | `false` | Enable HorizontalPodAutoscaler for APISIX (only when useDaemonSet is false) |
| autoscaling.maxReplicas | int | `100` | Maximum number of APISIX replicas |
| autoscaling.minReplicas | int | `1` | Minimum number of APISIX replicas |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target average CPU utilization percentage that triggers scaling |
| autoscaling.targetMemoryUtilizationPercentage | int | `80` | Target average memory utilization percentage that triggers scaling |
| autoscaling.version | string | `"v2"` | HPA version, the value is "v2" or "v2beta1", default "v2" |
| control.enabled | bool | `true` | Enable Control API |
| control.ingress | object | `{"annotations":{},"enabled":false,"hosts":[{"host":"apisix-control.local","paths":["/*"]}],"tls":[]}` | Using ingress access Apache APISIX Control service |
| control.ingress.annotations | object | `{}` | Ingress annotations |
| control.ingress.enabled | bool | `false` | Enable an Ingress resource in front of the Control API service |
| control.ingress.hosts | list | `[{"host":"apisix-control.local","paths":["/*"]}]` | Ingress host and path rules |
| control.ingress.tls | list | `[]` | Ingress TLS settings |
| control.service.annotations | object | `{}` | Control annotations |
| control.service.externalIPs | list | `[]` | IPs for which nodes in the cluster will also accept traffic for the servic |
| control.service.ip | string | `"127.0.0.1"` | which ip to listen on for Apache APISIX Control API |
| control.service.port | int | `9090` | which port to use for Apache APISIX Control API |
| control.service.servicePort | int | `9090` | Service port to use for Apache APISIX Control API |
| control.service.type | string | `"ClusterIP"` | Control service type |
| etcd | object | `{"auth":{"rbac":{"create":false,"rootPassword":""},"tls":{"certFilename":"","certKeyFilename":"","enabled":false,"existingSecret":"","sni":"","verify":true}},"autoCompactionMode":"periodic","autoCompactionRetention":"1h","containerSecurityContext":{"enabled":false},"enabled":true,"image":{"registry":"docker.io","repository":"bitnamilegacy/etcd","tag":"latest"},"prefix":"/apisix","replicaCount":3,"service":{"port":2379},"startupRetry":2,"timeout":30,"watchTimeout":50}` | etcd configuration use the FQDN address or the IP of the etcd |
| etcd.auth | object | `{"rbac":{"create":false,"rootPassword":""},"tls":{"certFilename":"","certKeyFilename":"","enabled":false,"existingSecret":"","sni":"","verify":true}}` | if etcd.enabled is true, set more values of bitnamilegacy/etcd helm chart |
| etcd.auth.rbac.create | bool | `false` | No authentication by default. Switch to enable RBAC authentication |
| etcd.auth.rbac.rootPassword | string | `""` | root password for etcd. Requires etcd.auth.rbac.create to be true. |
| etcd.auth.tls.certFilename | string | `""` | etcd client cert filename using in etcd.auth.tls.existingSecret |
| etcd.auth.tls.certKeyFilename | string | `""` | etcd client cert key filename using in etcd.auth.tls.existingSecret |
| etcd.auth.tls.enabled | bool | `false` | enable etcd client certificate |
| etcd.auth.tls.existingSecret | string | `""` | name of the secret contains etcd client cert |
| etcd.auth.tls.sni | string | `""` | specify the TLS Server Name Indication extension, the ETCD endpoint hostname will be used when this setting is unset. |
| etcd.auth.tls.verify | bool | `true` | whether to verify the etcd endpoint certificate when setup a TLS connection to etcd |
| etcd.autoCompactionMode | string | `"periodic"` | Auto compaction mode (periodic or revision), only used when etcd.enabled is true |
| etcd.autoCompactionRetention | string | `"1h"` | Auto compaction retention for mvcc key value store, only used when etcd.enabled is true |
| etcd.containerSecurityContext | object | `{"enabled":false}` | added for backward compatibility with old kubernetes versions, as seccompProfile is not supported in kubernetes < 1.19 |
| etcd.enabled | bool | `true` | install built-in etcd by default, set false if do not want to install built-in etcd together, this etcd is based on bitnamilegacy/etcd helm chart and latest bitnami docker image, only for development and testing purposes, if you want to use etcd in production, we recommend you to install etcd by yourself and use `externalEtcd` to connect it. |
| etcd.image | object | `{"registry":"docker.io","repository":"bitnamilegacy/etcd","tag":"latest"}` | docker image for built-in etcd |
| etcd.image.tag | string | `"latest"` | `bitnamilegacy/etcd` only provide `latest` tag now, ref: https://github.com/bitnami/containers/issues/83267, you can switch `etcd.image.repository` to `bitnamilegacy/etcd` to use old versioned tags. |
| etcd.prefix | string | `"/apisix"` | apisix configurations prefix |
| etcd.replicaCount | int | `3` | Number of etcd replicas, only used when etcd.enabled is true |
| etcd.service.port | int | `2379` | etcd client service port |
| etcd.startupRetry | int | `2` | The number of retries to etcd during startup |
| etcd.timeout | int | `30` | Set the timeout value in seconds for subsequent socket operations from apisix to etcd cluster |
| etcd.watchTimeout | int | `50` | Set the timeout value in seconds for watching etcd |
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
| extraVolumeMounts | list | `[]` | Additional `volumeMounts` for the APISIX container, See [Kubernetes Volumes](https://kubernetes.io/docs/concepts/storage/volumes/) for the detail. |
| extraVolumes | list | `[]` | Additional `volume`, See [Kubernetes Volumes](https://kubernetes.io/docs/concepts/storage/volumes/) for the detail. |
| fullnameOverride | string | `""` | String to fully override the chart fullname |
| global.imagePullSecrets | list | `[]` | Global Docker registry secret names as an array |
| hostNetwork | bool | `false` | Use the host's network namespace |
| image.pullPolicy | string | `"IfNotPresent"` | Apache APISIX image pull policy |
| image.repository | string | `"apache/apisix"` | Apache APISIX image repository |
| image.tag | string | `"3.17.0-ubuntu"` | Apache APISIX image tag Overrides the image tag whose default is the chart appVersion. |
| ingress | object | `{"annotations":{},"enabled":false,"hosts":[{"host":"apisix.local","paths":[]}],"servicePort":null,"tls":[]}` | Using ingress access Apache APISIX service |
| ingress-controller | object | `{"enabled":false,"webhook":{"enabled":false}}` | Ingress controller configuration |
| ingress-controller.enabled | bool | `false` | Enable the apisix-ingress-controller sub-chart |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.enabled | bool | `false` | Enable an Ingress resource in front of the APISIX service |
| ingress.hosts | list | `[{"host":"apisix.local","paths":[]}]` | Ingress host and path rules |
| ingress.servicePort | number | `nil` | Service port to send traffic. Defaults to `service.http.servicePort`. |
| ingress.tls | list | `[]` | Ingress TLS settings |
| initContainer.image | string | `"busybox"` | Init container image |
| initContainer.tag | float | `1.28` | Init container tag |
| metrics | object | `{"serviceMonitor":{"annotations":{},"enabled":false,"interval":"15s","labels":{},"name":"","namespace":""}}` | Observability configuration. |
| metrics.serviceMonitor.annotations | object | `{}` | @param serviceMonitor.annotations ServiceMonitor annotations |
| metrics.serviceMonitor.enabled | bool | `false` | Enable or disable Apache APISIX serviceMonitor |
| metrics.serviceMonitor.interval | string | `"15s"` | interval at which metrics should be scraped |
| metrics.serviceMonitor.labels | object | `{}` | @param serviceMonitor.labels ServiceMonitor extra labels |
| metrics.serviceMonitor.name | string | `""` | name of the serviceMonitor, by default, it is the same as the apisix fullname |
| metrics.serviceMonitor.namespace | string | `""` | namespace where the serviceMonitor is deployed, by default, it is the same as the namespace of the apisix |
| nameOverride | string | `""` | String to partially override the chart fullname |
| nodeSelector | object | `{}` | Node labels for Apache APISIX pod assignment |
| podAnnotations | object | `{}` | Annotations to add to each pod |
| podDisruptionBudget | object | `{"enabled":false,"maxUnavailable":1,"minAvailable":"90%"}` | See https://kubernetes.io/docs/tasks/run-application/configure-pdb/ for more details |
| podDisruptionBudget.enabled | bool | `false` | Enable or disable podDisruptionBudget |
| podDisruptionBudget.maxUnavailable | int | `1` | Set the maxUnavailable of podDisruptionBudget |
| podDisruptionBudget.minAvailable | string | `"90%"` | Set the `minAvailable` of podDisruptionBudget. You can specify only one of `maxUnavailable` and `minAvailable` in a single PodDisruptionBudget. See [Specifying a Disruption Budget for your Application](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#specifying-a-poddisruptionbudget) for more details |
| podSecurityContext | object | `{}` | Set the securityContext for Apache APISIX pods |
| priorityClassName | string | `""` | Set [priorityClassName](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#pod-priority) for Apache APISIX pods |
| rbac.create | bool | `false` | Whether RBAC resources (ClusterRole and ClusterRoleBinding) should be created |
| replicaCount | int | `1` | if useDaemonSet is true or autoscaling.enabled is true, replicaCount not become effective |
| resources | object | `{}` | Set pod resource requests & limits |
| securityContext | object | `{}` | Set the securityContext for Apache APISIX container |
| service.externalIPs | list | `[]` | IPs for which nodes in the cluster will also accept traffic for the service |
| service.externalTrafficPolicy | string | `"Cluster"` | Setting how the Service route external traffic. If you want to keep the client source IP, you can set this to Local, ref: https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip |
| service.http | object | `{"additionalContainerPorts":[],"containerPort":9080,"enabled":true,"servicePort":80}` | Apache APISIX service settings for http |
| service.http.additionalContainerPorts | list | `[]` | Support multiple http ports, See [Configuration](https://github.com/apache/apisix/blob/0bc65ea9acd726f79f80ae0abd8f50b7eb172e3d/conf/config-default.yaml#L24) |
| service.http.containerPort | int | `9080` | Container port APISIX listens on for HTTP traffic |
| service.http.enabled | bool | `true` | Enable plain HTTP listeners |
| service.http.servicePort | int | `80` | Kubernetes service port for HTTP traffic |
| service.labelsOverride | object | `{}` | Override default labels assigned to Apache APISIX gateway resources |
| service.stream | object | `{"enabled":false,"tcp":[],"udp":[]}` | Apache APISIX service settings for stream. L4 proxy (TCP/UDP) |
| service.stream.enabled | bool | `false` | Enable the stream (L4 proxy) subsystem |
| service.stream.tcp | list | `[]` | TCP proxy port list, element format: port number, or a map with `addr` and optional `tls` |
| service.stream.udp | list | `[]` | UDP proxy port list |
| service.tls | object | `{"servicePort":443}` | Apache APISIX service settings for tls |
| service.tls.servicePort | int | `443` | Kubernetes service port for HTTPS traffic |
| service.type | string | `"NodePort"` | Apache APISIX service type for user access itself |
| serviceAccount.annotations | object | `{}` | Annotations to add to the ServiceAccount |
| serviceAccount.create | bool | `false` | Whether a ServiceAccount should be created for the APISIX pods |
| serviceAccount.name | string | `""` | Name of the ServiceAccount to use. If not set and create is true, a name is generated from the chart fullname |
| timezone | string | `""` | timezone is the timezone where apisix uses. For example: "UTC" or "Asia/Shanghai" This value will be set on apisix container's environment variable TZ. You may need to set the timezone to be consistent with your local time zone, otherwise the apisix's logs may used to retrieve event maybe in wrong timezone. |
| tolerations | list | `[]` | List of node taints to tolerate |
| topologySpreadConstraints | list | `[]` | Topology Spread Constraints for pod assignment spread across your cluster among failure-domains ref: https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/#spread-constraints-for-pods |
| updateStrategy | object | `{}` | Update strategy of the workload (Deployment or DaemonSet), e.g. `type: RollingUpdate` |
| useDaemonSet | bool | `false` | set false to use `Deployment`, set true to use `DaemonSet` |
