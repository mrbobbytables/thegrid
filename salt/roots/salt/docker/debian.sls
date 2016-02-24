{% from "docker/map.jinja" import docker with context %}

remove-old-versions:
  pkgrepo.absent:
    - name: deb https://get.docker.com/{{ grains.os.lower() }} docker main
  pkg.purged:
    - pkgs:
      - "lxc-docker*"
      - "docker.io*"

docker-repo-prereqs:
  pkg.installed:
    - pkgs:
      - apt-transport-https
{# cannot use docker.opts|selectattr("storage-driver", "equalto", "aufs") in this instance to maintain #}
{# compatibility with ubuntu precise #}
{% if 'storage-driver' in docker.opts and docker.opts['storage-driver'][0] == 'aufs' %}
      - linux-image-extra-{{grains.kernelrelease}}
{% endif %}

docker-repo:
  pkgrepo.managed:
    - name: {{ docker.pkgrepo.name }}
    - humanname: Docker Official {{ grains.os }} Repo
    - keyid: {{ docker.pkgrepo.keyid }}
    - keyserver: {{ docker.pkgrepo.keyserver }}
    - file: /etc/apt/sources.list.d/docker.list
    - clean_file: true
    - refresh_db: true
    - require:
      - pkg: docker-repo-prereqs

docker-engine:
  pkg.installed:
    - name: {{ docker.pkg.name }}
    {% if 'version' in docker and docker.version is not none %}
    - version: "{{ docker.version }}*"
    {% endif %}
    - require:
      - pkgrepo: docker-repo

{% if docker.opts_type == 'systemd' %}
include: 
  - docker.systemd
{% elif docker.opts_type == 'default' %}

docker-config:
  file.managed:
    - name: /etc/default/docker
    - source: salt://docker/templates/{{ docker.opts_type }}-opts.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

docker-service:
  service.running:
    - name: docker
    - enable: true
    - restart: true
    - require:
      - pkg: docker-engine
    - watch:
      - file: /etc/default/docker
{% endif %}
