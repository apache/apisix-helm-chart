---
title: FAQ
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

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

### How to install APISIX only?

The Charts will install ETCD `3.4.14` by default. If you want to install Apache APISIX only, please set `etcd.enabled=false` and set `etcd.host={http://your_etcd_address:2379}`.

Please use the FQDN or the IP address of the ETCD cluster.

```shell
# if etcd export by kubernetes service need spell fully qualified name
helm install apisix apisix/apisix \
    --set etcd.enabled=false \
    --set etcd.host={http://etcd_node_1:2379\,http://etcd_node_2:2379}
```

### How to install Apache APISIX running in standalone mode?

helm install apisix apisix/apisix  --set deployment.mode=standalone --set etcd.enabled=false --set deployment.role=data_plane

### Why get 403 when I access Apache APISIX admin api?

We can define `admin.allow.ipList` in CIDR.

```shell
helm install apisix apisix/apisix \
    --set admin.allow.ipList="10.22.100.12/8" \
    --set admin.allow.ipList="172.0.0.0/24"
```

If you want to allow all IPs for a quick test, just set `admin.allow.ipList=""`

```shell
helm install apisix apisix/apisix \
    --set admin.allow.ipList=""
```

### Creating resources such as ApisixRoute has no effect?

1. [check the synchronization status of CRD](https://apisix.apache.org/docs/ingress-controller/tutorials/check-crd-status)
2. Find the current version of the CRD declaration in https://github.com/apache/apisix-ingress-controller, located in the samples/deploy/crd directory, overwrite and install them. 

Note: this operation may result in loss or corruption of historical data. You should back up the relevant data in advance.
