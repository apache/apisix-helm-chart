---
title: Apache APISIX Helm Chart
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
- [Helm v3.0+](https://helm.sh/docs/intro/quickstart/#install-helm)

## Install

To install the chart with release name `apisix`:

```shell
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install apisix apisix/apisix --create-namespace  --namespace apisix
```

### Start By One Line

To quickly experience Apache APISIX related components like Apache APISIX Dashboard and Apache APISIX Ingress Controller. For a quick installation, start by one line:

```shell
helm repo add apisix https://charts.apiseven.com && helm repo update && helm upgrade --install apisix apisix/apisix --create-namespace  --namespace apisix --set dashboard.enabled=true --set ingress-controller.enabled=true --set ingress-controller.config.apisix.serviceNamespace=apisix
```

## Uninstall

To uninstall/delete the `apisix` release:

```shell
helm uninstall apisix
```

## Seeking help

- Mailing List: Mail to dev-subscribe@apisix.apache.org, follow the reply to subscribe the mailing list.
- QQ Group - 578997126, 552030619
- [Slack Workspace](http://s.apache.org/slack-invite) - join `#apisix` on our Slack to meet the team and ask questions
- ![Twitter Follow](https://img.shields.io/twitter/follow/ApacheAPISIX?style=social) - follow and interact with us using hashtag `#ApacheAPISIX`
- [bilibili video](https://space.bilibili.com/551921247)
