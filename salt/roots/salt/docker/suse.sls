{% from "docker/map.jinja" import docker with context %}

docker-engine:
  pkg.installed:
    - name: {{ docker.pkg.name }}
    {% if 'version' in docker and docker.version is not none %}
    - version: "{{ docker.version }}*"
    {% endif %}

{% if docker.opts_type == 'systemd' %}
include: 
  - docker.systemd
{% endif %}
    
