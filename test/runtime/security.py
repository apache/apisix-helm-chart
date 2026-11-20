#!/usr/bin/env python3
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
"""Exercise the pinned image without a Kubernetes cluster; requires Docker."""
import subprocess, tempfile, pathlib, os, time, json
import yaml
chart = pathlib.Path(__file__).resolve().parents[2] / 'charts/apisix'
values = yaml.safe_load((chart / 'values.yaml').read_text())
metadata = yaml.safe_load((chart / 'Chart.yaml').read_text())
image_values = values['image']
reference = ('@' + image_values['digest']) if image_values.get('digest') else (':' + (image_values.get('tag') or str(metadata['appVersion'])))
image = os.environ.get('APISIX_RUNTIME_IMAGE', image_values['repository'] + reference)
root=pathlib.Path(tempfile.mkdtemp(prefix='apisix-runtime-review-'));root.chmod(0o777)
def run(args,**kw): return subprocess.run(args,text=True,check=True,**kw)
run(['docker','run','--rm','--read-only','--user','636:636','--cap-drop','ALL','--security-opt','no-new-privileges','--mount',f'type=bind,src={root},dst=/runtime','--entrypoint','sh',image,'-ec','cp -R /usr/local/apisix/conf /runtime/conf; cp -R /usr/local/apisix/logs /runtime/logs; chmod -R a+rwX /runtime/conf /runtime/logs'])
(root/'conf/config.yaml').write_text('''apisix:
  status:
    ip: 0.0.0.0
    port: 7085
nginx_config:
  worker_processes: 1
  error_log: /dev/stderr
deployment:
  role: data_plane
  role_data_plane:
    config_provider: yaml
''')
(root/'conf/apisix.yaml').write_text('routes: []\n#END\n')
name='apisix-review-runtime-'+str(os.getpid())
args=['docker','run','-d','--name',name,'--read-only','--user','636:636','--cap-drop','ALL','--security-opt','no-new-privileges','--mount',f'type=bind,src={root}/conf,dst=/usr/local/apisix/conf','--mount',f'type=bind,src={root}/logs,dst=/usr/local/apisix/logs','--tmpfs','/tmp:uid=636,gid=636','-e','APISIX_STAND_ALONE=true']
for path in ['client_body_temp','proxy_temp','fastcgi_temp','uwsgi_temp','scgi_temp']:args+=['--tmpfs',f'/usr/local/apisix/{path}:uid=636,gid=636']
args+=[image]
try:
 run(args)
 for i in range(20):
  result=subprocess.run(['docker','exec',name,'/usr/local/openresty/bin/resty','-e','local s=ngx.socket.tcp(); assert(s:connect("127.0.0.1",7085)); assert(s:send("GET /status/ready HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n")); local line=s:receive("*l"); assert(line and line:find("200"),line); print(line)'],capture_output=True,text=True)
  if result.returncode==0:break
  time.sleep(1)
 print('READINESS',result.returncode,result.stdout)
 run(['docker','logs',name])
 assert result.returncode==0,result.stderr
 run(['docker','exec',name,'/usr/local/openresty/bin/openresty','-p','/usr/local/apisix','-t'])
 t=time.monotonic();run(['docker','stop','-t','15',name]);print('STOP_SECONDS',time.monotonic()-t)
 print('RUNTIME_EVIDENCE',root)
finally:
 subprocess.run(['docker','rm','-f',name],capture_output=True)
