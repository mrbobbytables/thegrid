docker-engine-prereq:
  pkg.installed:
    - pkgs:
      - apt-transport-https
      - bridge-utils
      - linux-image-extra-{{grains.kernelrelease}}

docker-engine-install:
  pkgrepo.managed:
    - humanname: Official Docker Repository
    - name: deb https://apt.dockerproject.org/repo ubuntu-trusty main
    - file: /etc/apt/sources.list.d/docker.list
    - keyid: 2C52609D
    - keyserver: keyserver.ubuntu.com
  pkg.installed:
    - pkgs:
      - docker-engine
    - require:
      - pkgrepo: docker-engine-install
  service.running:
    - name: docker
    - enable: True
    - require:
      - pkg: docker-engine-install

