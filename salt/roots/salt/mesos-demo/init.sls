mesos-prereqs:
  pkg.installed:
    - name: bridge-utils

mesos-dns:
  file.managed:
    - name: /etc/resolvconf/resolv.conf.d/head
    - source: salt://mesos-demo/files/etc/resolvconf/resolv.conf.d/head
    - template: jinja
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

