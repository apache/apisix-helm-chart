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

Helm chart does not provide a direct way to deploy Apache APISIX running in standalone mode. You can install it in the following manner.

Create a `deploy.yaml` with the following content.

<Tabs
  groupId="version"
  defaultValue="3.0.0-beta"
  values={[
    {label: '3.0.0-beta', value: '3.0.0-beta'},
    {label: '2.15', value: '2.15'},
  ]}>

<TabItem value="3.0.0-beta">

```yaml
# deploy.yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: apisix-gw-config.yaml
data:
  config.yaml: |
    deployment:
      role: data_plane
      role_data_plane:
        config_provider: yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: apisix.yaml
data:
  apisix.yaml: |
    routes:
      -
        uri: /hi
        upstream:
          nodes:
            "127.0.0.1:1980": 1
          type: roundrobin
    #END
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apisix-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apisix-deployment
  strategy:
    rollingUpdate:
      maxSurge: 50%
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: apisix-deployment
    spec:
      terminationGracePeriodSeconds: 0
      containers: 
        - livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 1
            periodSeconds: 2
            successThreshold: 1
            tcpSocket:
              port: 9080
            timeoutSeconds: 2
          readinessProbe:
            failureThreshold: 3
            initialDelaySeconds: 1
            periodSeconds: 2
            successThreshold: 1
            tcpSocket:
              port: 9080
            timeoutSeconds: 2
          image: "apache/apisix:2.99.0-centos"
          imagePullPolicy: IfNotPresent
          name: apisix-deployment
          # Create a soft link to link the apisix.yaml file in the mount directory to /usr/local/apisix/conf/apisix.yaml.
          command: ["sh", "-c","ln -s /apisix-config/apisix.yaml /usr/local/apisix/conf/apisix.yaml && /docker-entrypoint.sh docker-start"]
          ports:
            - containerPort: 9080
              name: "http"
              protocol: "TCP"
            - containerPort: 9443
              name: "https"
              protocol: "TCP"
              
          volumeMounts:
            - mountPath: /usr/local/apisix/conf/config.yaml
              name: apisix-config-yaml-configmap
              subPath: config.yaml
            # configMap directory mounts
            - mountPath: /apisix-config
              name: apisix-admin
      volumes:
        - configMap:
            name: apisix-gw-config.yaml
          name: apisix-config-yaml-configmap
        - configMap:
            name: apisix.yaml
          name: apisix-admin
---
apiVersion: v1
kind: Service
metadata:
  name: apisix-service
spec:
  selector:
    app: apisix-deployment
  ports:
    - name: http
      port: 9080
      protocol: TCP
      targetPort: 9080
    - name: https
      port: 9443
      protocol: TCP
      targetPort: 9443
  type: NodePort
```

</TabItem>

<TabItem value="2.15">

```yaml
# deploy.yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: apisix-gw-config.yaml
data:
  config.yaml: |
    apisix:
      enable_admin: false
      config_center: yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: apisix.yaml
data:
  apisix.yaml: |
    routes:
      -
        uri: /hi
        upstream:
          nodes:
            "127.0.0.1:1980": 1
          type: roundrobin
    #END
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apisix-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apisix-deployment
  strategy:
    rollingUpdate:
      maxSurge: 50%
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: apisix-deployment
    spec:
      terminationGracePeriodSeconds: 0
      containers: 
        - livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 1
            periodSeconds: 2
            successThreshold: 1
            tcpSocket:
              port: 9080
            timeoutSeconds: 2
          readinessProbe:
            failureThreshold: 3
            initialDelaySeconds: 1
            periodSeconds: 2
            successThreshold: 1
            tcpSocket:
              port: 9080
            timeoutSeconds: 2
          image: "apache/apisix:2.15.0-alpine"
          imagePullPolicy: IfNotPresent
          name: apisix-deployment
          # Create a soft link to link the apisix.yaml file in the mount directory to /usr/local/apisix/conf/apisix.yaml.
          command: ["sh", "-c", "ln -s /apisix-config/apisix.yaml /usr/local/apisix/conf/apisix.yaml && /usr/bin/apisix init && /usr/bin/apisix init_etcd && /usr/local/openresty/bin/openresty -p /usr/local/apisix -g 'daemon off;'"]
          ports:
            - containerPort: 9080
              name: "http"
              protocol: "TCP"
            - containerPort: 9443
              name: "https"
              protocol: "TCP"
          volumeMounts:
            - mountPath: /usr/local/apisix/conf/config.yaml
              name: apisix-config-yaml-configmap
              subPath: config.yaml
            # configMap directory mounts
            - mountPath: /apisix-config
              name: apisix-admin
      volumes:
        - configMap:
            name: apisix-gw-config.yaml
          name: apisix-config-yaml-configmap
        - configMap:
            name: apisix.yaml
          name: apisix-admin
---
apiVersion: v1
kind: Service
metadata:
  name: apisix-service
spec:
  selector:
    app: apisix-deployment
  ports:
    - name: http
      port: 9080
      protocol: TCP
      targetPort: 9080
    - name: https
      port: 9443
      protocol: TCP
      targetPort: 9443
  type: NodePort
```

</TabItem>

</Tabs>

Apply the configuration in `deploy.yaml` to pod.

```shell
kubectl apply -f deploy.yaml
```

:::note
1. The mount of the `apisix.yaml` file requires the injection of the softlink command, so do not change the configMap mount directory to `/usr/local/apisix/conf`, to avoid other configuration files being overwritten.
2. The `apisix.yaml` is mounted as a configMap, so there will be a delay in reloading the rules after `apisix.yaml` is changed; please refer to this [document](https://kubernetes.io/docs/concepts/configuration/configmap/#mounted-configmaps-are-updated-automatically) for details. 
:::

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
