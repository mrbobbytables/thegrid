{% from 'docker/map.jinja' import compose with context %}

curl:
  pkg.installed


get-compose:
  cmd.run:
    - name: |
        curl -L https://github.com/docker/compose/releases/download/{{ compose.version }}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    - unless: docker-compose --version | grep -q {{ compose.version }}
    - require:
      - pkg: curl

{% if compose.completion == true %}
get-completion:
  cmd.wait:
    - name: |
        curl -L https://raw.githubusercontent.com/docker/compose/{{ compose.version }}/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose
    - watch:
      - cmd: get-compose
    - require:
      - pkg: curl
{% endif %}
