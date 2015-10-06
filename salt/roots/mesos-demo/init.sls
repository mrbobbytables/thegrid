mesos-demo-prereq:
  service.running:
    - name: docker
    - watch: 
      - file: /etc/default/docker
  file.managed:
    - name: /etc/default/docker
    - source: salt://mesos-demo/files/etc/default/docker
  require:
    - pkg: docker-engine

mesos-dns:
  file.replace:
    - name: /etc/resolvconf/resolv.conf.d/head
    - append_if_not_found: true
    - pattern: ^nameserver 127.0.1.1$
    - repl: nameserver 127.0.1.1
  cmd.run:
    - name: resolvconf -u

thegrid-set-host-ip-bashrc:
  file.replace:
    - name: /home/vagrant/.bashrc
    - append_if_not_found: true
    - pattern: ^export\sHOST_IP=.*
    - repl: export HOST_IP={{grains['ip_interfaces']['eth1'][0]}}

thegrid-set-host-ip-sudoers:
  file.managed:
    - name: /etc/sudoers.d/thegrid
    - user: root
    - group: root
    - mode: 440
    - contents: Defaults  env_keep +="HOST_IP"

