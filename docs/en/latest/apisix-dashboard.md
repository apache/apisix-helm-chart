---
title: Apache APISIX Dashboard Helm Chart
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

> [!WARNING]
> This chart is deprecated and no longer maintained.
>
> In short:
> The old version of the APISIX Dashboard lacks maintenance from community members,
> while the brand new Dashboard will be directly integrated into APISIX,
> eliminating the need for the current chart.
>
> For details, please see <https://github.com/apache/apisix-dashboard/issues/2981>.
>
> If you are still using the old version of the APISIX Dashboard,
> you can continue to use the chart.

## Prerequisites

- [Kubernetes 1.12+](https://kubernetes.io/docs/setup/)
- [Apache APISIX](https://apisix.apache.org/docs/apisix/installation-guide/)
- [Helm v3.0+](https://helm.sh/docs/intro/quickstart/#install-helm)

## Install

To install the chart with release name `apisix-dashboard`:

```shell
helm repo add apisix https://apache.github.io/apisix-helm-chart
helm repo update
helm install apisix-dashboard apisix/apisix-dashboard --create-namespace --namespace apisix
```

## Uninstall

To uninstall/delete the `apisix-dashboard` release:

```shell
helm uninstall apisix-dashboard
```
