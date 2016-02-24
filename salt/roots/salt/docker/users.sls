{% from "docker/map.jinja" import docker with context %}

create-docker-group:
  group.present:
    - name: docker
    - system: true
{% if 'users' in docker and docker.users|length > 0 %}
    - members:
{% for user in docker.users %}
      - {{ user }}
{% endfor %}
{% endif %}
