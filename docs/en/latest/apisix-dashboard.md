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

## Install

To install the chart with release name `apisix-dashboard`:

```shell
$ helm repo add apisix https://charts.apiseven.com
$ helm repo update
$ helm install apisix-dashboard apisix/apisix-dashboard
```

- Configure the custom plug-in JSONSchema [How to get jsonschema?](https://apisix.apache.org/docs/dashboard/FAQ/#4-after-modifying-the-plugin-schema-or-creating-a-custom-plugin-in-apache-apisix-why-cant-i-find-it-on-the-dashboard)

```shell
helm install <name> apisix/apisix-dashboard . -n <namespace> --set-file config.schema=./schema.json
```

## Uninstall

To uninstall/delete the `apisix-dashboard` release:

```shell
$ helm uninstall apisix-dashboard
```

## Configuration

Parameter | Description | Default
------------ | ------------- | ------------- 
 Config.conf |  |  
 config.conf.listen.host | the address on which the `Manager API` should listen. | 0.0.0.0
 config.conf.listen.port | The port on which the `Manager API` should listen. | 9000
 config.conf.etcd.endpoints | upports defining multiple etcd host addresses for an etcd cluster | [apisix-etcd:2379]
 config.conf.etcd.prefix | apisix config's prefix in etcd | /apisix
 config.conf.etcd.username | ignore etcd username if not enable etcd auth | nil
 config.conf.etcd.password | ignore etcd password if not enable etcd auth | nil
 config.conf.log.errorLog.level | supports levels, lower to higher: debug, info, warn, error, panic, fatal | warn
 config.conf.log.errorLog.filePath | supports relative path, absolute path, standard output | /dev/stderr
 config.conf.log.accessLog.filePath | supports relative path, absolute path, standard output | /dev/stdout
 Config.authentication |  |  
 config.authentication.secert | secret for jwt token generation. | secert
 config.authentication.expireTime | jwt token expire time, in second | 3600
 config.authentication.users | username and password for login `Manager API` | 
 Config.schema |  |  
 config.schema | Jsonchema exported on the Apisix server [How to get jsonschema?](https://apisix.apache.org/docs/dashboard/FAQ/#4-after-modifying-the-plugin-schema-or-creating-a-custom-plugin-in-apache-apisix-why-cant-i-find-it-on-the-dashboard) | 