docker-config:
  file.managed:
    - name: /etc/systemd/system/docker.service.d/docker-opts.conf
    - source: salt://docker/templates/systemd-opts.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
  module.wait:
    - name: service.systemctl_reload
    - watch:
      - file: docker-config

docker-service:
  service.running:
    - name: docker
    - enable: true
    - restart: true
    - require:
      - pkg: docker-engine
    - watch:
      - file: docker-config


