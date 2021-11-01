## Apache APISIX for Kubernetes

Apache APISIX is a dynamic, real-time, high-performance API gateway.

APISIX provides rich traffic management features such as load balancing, dynamic upstream, canary release, circuit breaking, authentication, observability, and more.

You can use Apache APISIX to handle traditional north-south traffic, as well as east-west traffic between services. It can also be used as a [k8s ingress controller](https://github.com/apache/apisix-ingress-controller/).

This chart bootstraps all the components needed to run Apache APISIX on a Kubernetes Cluster using [Helm](https://helm.sh).


## TL;DR

```sh
helm repo add apisix https://charts.apiseven.com
helm repo update

helm install apisix/apisix --generate-name
```

## Prerequisites

* Kubernetes v1.14+
* Helm v3+


## Install

To install the chart with the release name `my-apisix`:

```sh
helm repo add apisix https://charts.apiseven.com
helm repo update

helm install my-apisix apisix/apisix
```

## Uninstall

 To uninstall/delete a Helm release `my-apisix`:

 ```sh
helm delete my-apisix
 ```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Parameters

The following tables lists the configurable parameters of the apisix chart and their default values per section/component:

### Global parameters

| Parameter                 | Description                                     | Default                                                 |
|---------------------------|-------------------------------------------------|---------------------------------------------------------|
| `global.imagePullSecrets` | Global Docker registry secret names as an array | `[]` (does not add image pull secrets to deployed pods) |


### apisix parameters

| Parameter                                | Description                                         | Default                                                 |
|------------------------------------------|-----------------------------------------------------|---------------------------------------------------------|
| `apisix.enabled`                         | Enable or disable Apache APISIX itself              | `true`                                                  |
| `apisix.image.repository`                | Apache APISIX image repository                      | `apache/apisix`                                         |
| `apisix.image.tag`                       | Apache APISIX image tag                             | `{TAG_NAME}` (the latest Apache APISIX image tag)       |
| `apisix.image.pullPolicy`                | Apache APISIX image pull policy                     | `IfNotPresent`                                          |
| `apisix.replicaCount`                    | Apache APISIX deploy replica count                  | `1`                                                     |
| `apisix.podAnnotations`                  | Annotations to add to each pod                      | `{}`                                                    |
| `apisix.podSecurityContext`              | Set the securityContext for Apache APISIX pods      | `{}`                                                    |
| `apisix.securityContext`                 | Set the securityContext for Apache APISIX container | `{}`                                                    |
| `apisix.resources`                       | Set pod resource requests & limits                  | `{}`                                                    |
| `apisix.nodeSelector`                    | Node labels for Apache APISIX pod assignment        | `{}`                                                    |
| `apisix.tolerations`                     | List of node taints to tolerate                     | `{}`                                                    |
| `apisix.affinity`                        | Set affinity for Apache APISIX deploy               | `{}`                                                    |
| `apisix.podAntiAffinity.enabled`         | Enable or disable podAntiAffinity                   | `false`                                                 |


### gateway parameters

Apache APISIX service parameters, this determines how users can access itself.

| Parameter                       | Description                                                                                                                                                                         | Default    |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|
| `gateway.type`                  | Apache APISIX service type for user access itself                                                                                                                                   | `NodePort` |
| `gateway.externalTrafficPolicy` | Setting how the Service route external traffic                                                                                                                                      | `Cluster`  |
| `gateway.http`                  | Apache APISIX service settings for http                                                                                                                                             |            |
| `gateway.tls`                   | Apache APISIX service settings for tls                                                                                                                                              |            |
| `gateway.tls.existingCASecret`  | Specifies the name of Secret contains trusted CA certificates in the PEM format used to verify the certificate when APISIX needs to do SSL/TLS handshaking with external services (e.g. etcd) | `""`       |
| `gateway.tls.certCAFilename`    | filename be used in the `gateway.tls.existingCASecret`                                                                                                                                          | `""`       |
| `gateway.stream`                | Apache APISIX service settings for stream                                                                                                                                           |            |
| `gateway.ingress`               | Using ingress access Apache APISIX service                                                                                                                                          |            |


### admin parameters

| Parameter                  | Description                                                                      | Default                                                 |
|----------------------------|----------------------------------------------------------------------------------|---------------------------------------------------------|
| `admin.enabled`            | Enable or disable Apache APISIX admin API                                        | `true`                                                  |
| `admin.port`               | which port to use for Apache APISIX admin API                                    | `9180`                                                  |
| `admin.servicePort`        | Service port to use for Apache APISIX admin API                                  | `9180`                                                  |
| `admin.type`               | Apache APISIX admin API service type                                             | `ClusterIP`                                             |
| `admin.externalIPs`        | IPs for which nodes in the cluster will also accept traffic for the servic       | `[]`                                                    |
| `admin.cors`               | Apache APISIX admin API support CORS response headers                            | `true`                                                  |
| `admin.credentials.admin`  | Apache APISIX admin API admin role credentials                                   | `edd1c9f034335f136f87ad84b625c8f1`                      |
| `admin.credentials.viewer` | Apache APISIX admin API viewer role credentials                                  | `4054f7cf07e344346cd3f287985e76a2`                      |
| `admin.allow.ipList`       | the IP range allowed to Apache APISIX admin API                                  | `true`                                                  |

### custom configuration snippet parameters

| Parameter                        | Description                                                                                        | Default |
|----------------------------------|----------------------------------------------------------------------------------------------------|---------|
| `configurationSnippet.main`      | Add custom Nginx configuration (main block) to nginx.conf                                          | `{}`    |
| `configurationSnippet.httpStart` | Add custom Nginx configuration (http block) to nginx.conf                                          | `{}`    |
| `configurationSnippet.httpEnd`   | Add custom Nginx configuration (http block) to nginx.conf, will be put at the bottom of http block | `{}`    |
| `configurationSnippet.httpSrv`   | Add custom Nginx configuration (server block) to nginx.conf                                        | `{}`    |
| `configurationSnippet.httpAdmin` | Add custom Nginx configuration (Admin API server block) to nginx.conf                              | `{}`    |
| `configurationSnippet.stream`    | Add custom Nginx configuration (stream block) to nginx.conf                                        | `{}`    |

### etcd parameters

| Parameter                       | Description                                                                                                                                                      | Default                     |
|---------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------|
| `etcd.enabled`                  | use built-in etcd                                                                                                                                                | `true`                      |
| `etcd.host`                     | if `etcd.enabled` is false, use external etcd, support multiple address, if your etcd cluster enables TLS, please use https scheme, e.g. https://127.0.0.1:2379. | `["http://etcd.host:2379"]` |
| `etcd.prefix`                   | apisix configurations prefix                                                                                                                                     | `/apisix`                   |
| `etcd.timeout`                  | Set the timeout value in seconds for subsequent socket operations from apisix to etcd cluster                                                                    | `30`                        |
| `etcd.auth.rbac.enabled`        | enable auth for etcd                                                                                                                                             | `false`                     |
| `etcd.auth.rbac.user`           | root username for etcd                                                                                                                                           | `""`                        |
| `etcd.auth.rbac.password`       | root password for etcd                                                                                                                                           | `""`                        |
| `etcd.auth.tls.enabled`         | enable etcd client certificate                                                                                                                                   | `false`                     |
| `etcd.auth.tls.existingSecret`  | name of the secret contains etcd client cert                                                                                                                     | `""`                        |
| `etcd.auth.tls.certFilename`    | etcd client cert filename using in `etcd.auth.tls.existingSecret`                                                                                                | `""`                        |
| `etcd.auth.tls.certKeyFilename` | etcd client cert key filename using in `etcd.auth.tls.existingSecret`                                                                                            | `""`                        |
| `etcd.auth.tls.verify`          | whether to verify the etcd endpoint certificate when setup a TLS connection to etcd                                                                              | `true`                      |

If etcd.enabled is true, set more values of bitnami/etcd helm chart use etcd as prefix

### plugins and stream_plugins parameters 

Default enabled plugins. See [configmap template](https://github.com/apache/apisix-helm-chart/blob/master/charts/apisix/templates/configmap.yaml) for details.

### dashboard parameters

Configurations for apisix-dashboard sub chart.


### ingress-controller parameters

Configurations for Apache APISIX ingress-controller sub chart.
