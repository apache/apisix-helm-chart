---
title: Apache APISIX Ingress Controller Helm Chart
---

<!--
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
-->

## Prerequisites

- [Kubernetes 1.12+](https://kubernetes.io/docs/setup/)
- [Apache APISIX](https://apisix.apache.org/docs/apisix/installation-guide/)
- [Helm v3.0+](https://helm.sh/docs/intro/quickstart/#install-helm)

## Install

To install apisix-ingress-controller which release name is `apisix-ingress-controller`:

```bash
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install apisix-ingress-controller apisix/apisix-ingress-controller --namespace ingress-apisix --create-namespace
```

Note: APISIX Ingress Controller will try to establish a connection with APISIX admin in the location specified by `apisix.serviceName` and `apisix.serviceNamespace` values following the naming convention `<serviceName.serviceNamespace.svc.clusterDomain>`. You can override this behavior to specify a fully custom location by setting the `apisix.serviceFullname` value.

## Uninstall

To uninstall/delete the `apisix-ingress-controller` release:

```bash
helm uninstall apisix-ingress-controller --namespace ingress-apisix
```

## Deployment Options

### ingress version

By default apisix-ingress-controller watches the [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) resources in api group `networking/v1`, however, if your Kubernetes cluster is prior to `v1.19`, you need to change the ingress watching version.

If your Kubernetes version is older than `v1.14`, then:

```shell
helm install apisix-ingress-controller apisix/apisix-ingress-controller --namespace ingress-apisix --set config.kubernetes.ingressVersion=extensions/v1beta1
```

Or if your Kubernetes version is between `v1.14` and `v1.19`, try below:

```shell
helm install apisix-ingress-controller apisix/apisix-ingress-controller --namespace ingress-apisix --set config.kubernetes.ingressVersion=networking/v1beta1
```

## Upgrade Considerations

### CRD

CRDs upgrading is special as helm chart will skip to apply these resources when they already exist.

> With the arrival of Helm 3, we removed the old crd-install hooks for a more simple methodology. There is now a special directory called crds that you can create in your chart to hold your CRDs. These CRDs are not templated, but will be installed by default when running a helm install for the chart. If the CRD already exists, it will be skipped with a warning. If you wish to skip the CRD installation step, you can pass the --skip-crds flag.

In such a case, you may need to apply these CRDs by yourself.

```shell
cd /path/to/apisix-ingress-controller
kubectl apply -k samples/deploy/crd/
```
