/usr/local/bin/docker-compose:
  file.managed:
    - source: https://github.com/docker/compose/releases/download/{{grains['compose_version']}}/docker-compose-Linux-x86_64
    - source_hash: sha256={{grains['compose_exec_hash']}}
    - mode: 755

/etc/bash_completion.d/docker-compose:
  file.managed:
    - source: https://raw.githubusercontent.com/docker/compose/{{grains['compose_version']}}/contrib/completion/bash/docker-compose
    - source_hash: sha256={{grains['compose_bash_hash']}}
