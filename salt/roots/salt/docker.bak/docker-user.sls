docker-user:
  user.present:
    - name:  {{grains['docker_user']}}
    - optional_groups: 
      - docker

