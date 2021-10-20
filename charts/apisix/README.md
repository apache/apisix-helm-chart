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

| Parameter                       | Description                                                                      | Default                                                 |
|---------------------------------|----------------------------------------------------------------------------------|---------------------------------------------------------|
| `gateway.type`                  | Apache APISIX service type for user access itself                                | `NodePort`                                              |
| `gateway.externalTrafficPolicy` | Setting how the Service route external traffic                                   | `Cluster`                                               |
| `gateway.http`                  | Apache APISIX service settings for http                                          |                                                         |
| `gateway.tls`                   | Apache APISIX service settings for tls                                           |                                                         |
| `gateway.stream`                | Apache APISIX service settings for stream                                        |                                                         |
| `gateway.ingress`               | Using ingress access Apache APISIX service                                       |                                                         |


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

### plugins and stream_plugins parameters 

Default enabled plugins. See [configmap template](https://github.com/apache/apisix-helm-chart/blob/master/charts/apisix/templates/configmap.yaml) for details.

### etcd parameters

Configurations for etcd sub chart.

### dashboard parameters

Configurations for apisix-dashboard sub chart.


### ingress-controller parameters

Configurations for Apache APISIX ingress-controller sub chart.
