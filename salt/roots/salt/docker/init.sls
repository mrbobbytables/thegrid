{% from 'docker/map.jinja' import docker with context %}
{% if grains.os_family == 'Debian' %}
include:
  - docker.debian
{% elif grains.os_family == 'RedHat' %}
include:
  - docker.redhat
{% elif grains.os_family == 'Suse' %}
include:
  - docker.suse
{% endif %}
