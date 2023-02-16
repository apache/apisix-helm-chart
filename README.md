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

# Apache APISIX Helm Charts

Apache APISIX Helm Charts provide the installation of [Apache APISIX](https://github.com/apache/apisix#apache-apisix) components for kubernetes.

- [Apache APISIX Helm Chart](./docs/en/latest/apisix.md)
- [Apache APISIX Dashboard Helm Chart](./docs/en/latest/apisix-dashboard.md)
- [Apache APISIX Ingress Controller Helm Chart](./docs/en/latest/apisix-ingress-controller.md)

Currently, APISIX Ingress Controller automatically manipulates some APISIX resources, which is not very compatible with APISIX Dashboard. In addition, users should not modify resources labeled `managed-by: apisix-ingress-controllers` via APISIX Dashboard.

## Compatibility matrix

|            | APISIX | APISIX Ingress | APISIX Dashboard |
| :--------: | :----: | :------------: | :--------------: |
| Chart v1.x |  v3.x  |      v1.x      |       v3.x       |
| Chart v0.x |  v2.x  |      v1.x      |       v2.x       |
