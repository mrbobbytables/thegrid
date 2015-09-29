#!/bin/bash


build_containers() {
  local container_list=""
  local build_list=()
  if [[ ! $1 ]]; then
    container_list="ubuntu-base,mesos-base,mesos-master,mesos-slave,mesos-slave-jenkins,mesos-dns,zookeeper,marathon,chronos,bamboo,openvpn,jenkins,jenkins-build-base"
  else
    container_list="$1"
  fi

  build_list+=(${container_list//,/ })
  for container in "${build_list[@]}"; do
    if [[ -f containers/$container/VERSION ]]; then
      docker build -t "mrbobbytables/$container:$(<containers/$container/VERSION)" "containers/$container"
      docker tag "mrbobbytables/$container:$(<containers/$container/VERSION)" "mrbobbytables/$container:latest"
    else
      docker build -t "mrbobbytables/$container" "containers/$container"
    fi
  done
}

clone_containers() {
  local container_list=""
  local clone_list=()
  if [[ ! $1 ]]; then
    container_list="ubuntu-base,mesos-base,mesos-master,mesos-slave,mesos-slave-jenkins,mesos-dns,zookeeper,marathon,chronos,bamboo,openvpn,jenkins,jenkins-build-base"
  else
    container_list="$1"
  fi
  clone_list+=(${container_list//,/ })
  for container in "${clone_list[@]}"; do
    if [[ ! -d "containers/$container" ]]; then
      mkdir -p "containers/$container"
      git clone "https://github.com/mrbobbytables/$container.git" "containers/$container"
    else
      git -C "containers/$container" pull
    fi
  done
  if [[ "$EUID" -eq 0 ]]; then
    chown -R "$SUDO_USER:$SUDO_USER" containers/
  fi
}

pull_containers() {
  local container_list=""
  local pull_list=()
  if [[ ! $1 ]]; then
    local container_list="ubuntu-base,mesos-base,mesos-master,mesos-slave,mesos-slave-jenkins,mesos-dns,zookeeper,marathon,chronos,bamboo,openvpn,jenkins,jenkins-build-base"
  else
    container_list="$1"
  fi

  pull_list+=(${container_list//,/ })
  for container in "${pull_list[@]}"; do
    docker pull "mrbobbytables/$container"
  done
}

check_compose() {
  local dc_check=""
  echo "Checking Docker Compose Dependencies..."
  if [[ ! -x /usr/local/bin/docker-compose ]]; then
    echo "docker-compose was not found. Cannot continue without installation."
    echo "To install, please execute the following command:"
    echo "curl -L https://github.com/docker/compose/releases/download/VERSION_NUM/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose"
    exit 1
  fi
}

get_host_ip() {
  if [[ ! $HOST_IP ]]; then  
    local netdev=""
    local local_ip=""
    local bind_ip=""
    netdev="$(ip link show | grep -m 1 'state UP' | awk '{print $2}' | grep -Po '.*(?=:)')"
    local_ip="$(ip addr show "$netdev" | grep -m 1 -P -o '(?<=inet )[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')"

    read -p "What is the Forward facing IP you wish to bind services to? [default: $local_ip]" bind_ip
    bind_ip="${bind_ip:-"$local_ip"}"
    export HOST_IP="$bind_ip"
  else
    "$HOST_IP already defined. Using $HOST_IP"
  fi
}

post_marathon() {
  if [[ "$(docker inspect -f '{{.State.Running}}' marathon)" == "true" ]]; then
    local marathon_ip=""
    local marathon_app=""
    if [[ $# -eq 1 ]]; then
      marathon_ip="$(docker inspect --format='{{.NetworkSettings.IPAddress}}' marathon)"
      marathon_app="local/marathon_apps/$1.container.marathon.local.json"
    else
      marathon_ip="$1"
      marathon_app="local/marathon_apps/$2.host.marathon.local.json"
    fi
    if [[ -f "$marathon_app" ]]; then
      curl -X POST -H "Content-Type: application/json" "$marathon_ip:8080/v2/apps" -d "@$marathon_app"
    else
     echo "$marathon_app not found."
     exit 1
    fi
  else
    echo "Marathon container is not running. Cannot POST."
    exit 1
 fi
}

put_marathon() {
  if [[ "$(docker inspect -f '{{.State.Running}}' marathon)" == "true" ]]; then
    local marathon_ip=""
    local marathon_app=""
    if [[ $# -eq 1 ]]; then
      marathon_ip="$(docker inspect --format='{{.NetworkSettings.IPAddress}}' marathon)"
      marathon_app="local/marathon_apps/$1.container.marathon.local.json"
    else
      marathon_ip="$1"
      marathon_app="local/marathon_apps/$2.host.marathon.local.json"
    fi
    if [[ -f "$marathon_app" ]]; then
      curl -X PUT -H "Content-Type: application/json" "$marathon_ip:8080/v2/apps" -d "@$marathon_app"
    else
     echo "$marathon_app not found."
     exit 1
    fi
  else
    echo "Marathon container is not running. Cannot PUT."
    exit 1
 fi
}



del_marathon() {
  if [[ "$(docker inspect -f '{{.State.Running}}' marathon)" == "true" ]]; then
    local marathon_ip=""
    local marathon_app=""
    if [[ $# -eq 1 ]]; then
      marathon_ip="$(docker inspect --format='{{.NetworkSettings.IPAddress}}' marathon)"
      marathon_app="$1"
    else
      marathon_ip="$1"
      marathon_app="$2"
      echo "$marathon_ip:8080/v2/apps/$marthon_app"
      curl -X DELETE "$marathon_ip:8080/v2/apps/$marathon_app"
    fi
  else
    echo "Marathon container is not running. Cannot DELETE."
    exit 1
 fi
}


post_chronos() {
  if [[ "$(docker inspect -f '{{.State.Running}}' chronos)" == "true" ]]; then
    local chronos_ip=""
    local chronos_job=""
    if [[ $# -eq 1 ]]; then
      chronos_ip="$(docker inspect --format='{{.NetworkSettings.IPAddress}}' chronos)"
      chronos_job="local/chronos_jobs/$1.chronos.local.json"
    else
      chronos_ip="$1"
      chronos_job="local/chronos_jobs/$2.chronos.local.json"
    fi
    if [[ -f "$chronos_job" ]]; then
      curl -X POST -H "Content-Type: application/json" "$chronos_ip:4400/scheduler/iso8601" -d "@$chronos_job"
    else
     echo "$chronos_job not found."
     exit 1
    fi
  else
    echo "Chronos container is not running. Cannot POST."
    exit 1
 fi
}

del_chronos() {
  if [[ "$(docker inspect -f '{{.State.Running}}' chronos)" == "true" ]]; then
    local chronos_ip=""
    local chronos_job=""
    if [[ $# -eq 1 ]]; then
      chronos_ip="$(docker inspect --format='{{.NetworkSettings.IPAddress}}' chronos)"
      chronos_job="$1"
    else
      chronos_ip="$1"
      chronos_job="$2"
      curl -X DELETE -H "Content-Type: application/json" "$chronos_ip:4400/scheduler/job/$chronos_job"
    fi
  else
    echo "Chronos container is not running. Cannot DELETE."
    exit 1
 fi
}

start_cluster() {
  read -p "Start Cluster? NOTE: This will update and overwrite docker-compose.yml with compose_templates/$1.yml (Y/N) [Default: Y]" st_clstr
  st_clstr=${st_clstr:-y}
  case "${st_clstr,,}" in
  y|yes)
    cp "compose_templates/$1.yml" docker-compose.yml
    if [[ "$1" == "host" ]]; then
      if [[ "$EUID" -eq 0 ]]; then
        host_mod_configs
        chown "$SUDO_USER:$SUDO_USER" docker-compose.yml
        chown -R "$SUDO_USER:$SUDO_USER" local/
      else
        host_mod_configs
      fi
    fi
    exec /usr/local/bin/docker-compose up  -d --force-recreate
  ;;
  n|no|*)
    echo "Start cluster with: docker-compose up -d --force-recreate"
  ;;
  esac 
}

stop_cluster() {
  /usr/local/bin/docker-compose stop --timeout 30
  if [[ $(docker ps | grep "mesos-*" | awk '{print $NF}') ]]; then
    for container in $(docker ps | grep "mesos-*" | awk '{print $NF}'); do
      echo "Stopping $container"
      docker stop "$container"
   done
  fi
}

host_check_prereq() {
  echo "Checking Host Dependencies..."
  if [[ "$EUID" -ne 0 ]]; then
    echo "This action requires root privleges to continue"
    exit 1
  fi

  local brctl_check=""
  brctl_check=$(brctl --version 2>&1)
  if echo "$brctl_check" | grep -q "command not found"; then
    echo "brctl (bridge-utils) was not found. Cannot continue without installation."
    exit 1
  fi
}


host_create_bridge() {
  if [[ ! -d /sys/class/net/mesos0 ]]; then
    brctl addbr mesos0
    ip addr add 192.168.111.1/24 dev mesos0
    ip link set dev mesos0 up
    echo "Bridge mesos0 created."
 else
    echo "Bridge mesos0 already exists."
 fi
 
}

host_del_bridge() {
  if [[ -d /sys/class/net/mesos0 ]]; then
    ip link set mesos0 down
    brctl delbr mesos0
    echo "Bridge mesos0 deleted."
  else
    echo "Bridge mesos0 does not exist"
  fi
}


host_create_service_ips() {
  echo "Adding Service IPs..."
  host_add_mesos0_ip "192.168.111.10" "zk"
  host_add_mesos0_ip "192.168.111.11" "master"
  host_add_mesos0_ip "192.168.111.12" "marathon"
  host_add_mesos0_ip "192.168.111.13" "chronos"
  host_add_mesos0_ip "192.168.111.14" "jenkins"
  host_add_mesos0_ip "192.168.111.15" "dns"
  host_add_mesos0_ip "192.168.111.16" "bamboo"
  host_add_mesos0_ip "192.168.111.17" "ovpn"
 }

host_add_mesos0_ip() {
  if [[ -d /sys/class/net/mesos0 ]];then
    if ! ip addr show mesos0 | grep -q "$2"; then
      ip addr add "$1/24" dev mesos0 label "mesos0:$2"
      echo "ip $1/24 added to mesos0 with label mesos0:$2"
    else
      echo "$2 already defined."
    fi
  else
    echo "Bridge mesos0 does not exist. It must be created first."
  fi
}

host_del_mesos0_ip() {
  if echo "$1" | grep -qE "192.168.111.[0-9]{1,3}"; then
    ip addr del "$1/24" dev mesos0
    echo "ip $1 deleted."
  elif ip addr show label "mesos0:$1" | grep -qE "192.168.111.[0-9]{1,3}/24"; then
    local label_ip=""
    label_ip="$(ip addr show label "mesos0:$1" | grep -oE "192.168.111.[0-9]{1,3}/24")"
    ip addr del "$label_ip" dev mesos0
    echo "mesos0:$1 ($label_ip) deleted."
  else
    echo "Could not detect $1 bound to mesos0"
  fi
}

host_mod_configs() {
  if [[ ! $HOST_IP ]]; then
    get_host_ip
  fi

  sed -i -e "s|<mesos_tmp>|$(pwd)/tmp|g"  \
         -e "s|<pub_ip>|$HOST_IP|g"       \
         docker-compose.yml
  sed -i -e "s|\"OVPN_LOCAL\": \".*\"|\"OVPN_LOCAL\": \"$HOST_IP\"|g" \
            local/marathon_apps/ovpn.host.marathon.local.json
}

host_config_ovpn() {
  local ovpn_client_conf=""
  local ovpn_local_dir=""
  ovpn_client_conf="local/client-$HOST_IP.ovpn"
  ovpn_local_dir=local/containers/local-openvpn
  docker pull mrbobbytables/easyrsa
  echo "#################### READ THIS ####################"
  echo "########### USE DEFAULTS FOR SERVER AND ###########"
  echo "############# CLIENT CERTIFICATE NAME #############"
  echo "#################### READ THIS ####################"
  read -p "Begin cert generation [Press [Enter] to continue."

  mkdir -p local/certs/
  docker run --rm -it -v "$(pwd)/local/certs/":/target:rw mrbobbytables/easyrsa
  chown -R "$SUDO_USER:$SUDO_USER" local/certs/

  mkdir -p "$ovpn_local_dir/skel/etc/openvpn/certs"
  echo "FROM mrbobbytables/openvpn" > "$ovpn_local_dir/Dockerfile"
  echo "COPY ./skel /" >> "$ovpn_local_dir/Dockerfile"
  cp local/certs/server-certs/* "$ovpn_local_dir/skel/etc/openvpn/certs"
  docker build -t local-openvpn local/containers/local-openvpn/

  echo "float" > "$ovpn_client_conf"
  echo "port 1194" >> "$ovpn_client_conf"
  echo "proto udp" >> "$ovpn_client_conf"
  echo "dev tun" >> "$ovpn_client_conf"
  echo "dev-type tun" >> "$ovpn_client_conf"
  echo "remote $HOST_IP" >> "$ovpn_client_conf"
  echo "ping 10" >> "$ovpn_client_conf"
  echo "persist-tun" >> "$ovpn_client_conf"
  echo "persist-key" >> "$ovpn_client_conf"
  echo "comp-lzo yes" >> "$ovpn_client_conf"
  echo "client" >> "$ovpn_client_conf"
  echo "verb 1" >> "$ovpn_client_conf"
  echo "<ca>" >> "$ovpn_client_conf"
  cat local/certs/client-certs/ca.crt >> "$ovpn_client_conf"
  echo "</ca>" >> "$ovpn_client_conf"
  echo "<cert>" >> "$ovpn_client_conf"
  openssl x509 -in local/certs/client-certs/client.crt -outform PEM >> "$ovpn_client_conf"
  echo "</cert>" >> "$ovpn_client_conf"
  echo "<key>" >> "$ovpn_client_conf"
  cat local/certs/client-certs/client.key >> "$ovpn_client_conf"
  echo "</key>" >> "$ovpn_client_conf"   
}


usage_container() {
cat <<EOF
Usage: thegrid.sh container [bootstrap|framework|stop|up]

 - bootstrap [build|clone|pull] <containers> -- NOTE: requires root (sudo)
   Defaults to the following containers:
   [ubuntu-base,mesos-base,mesos-master,mesos-slave,zookeeper,marathon,chronos]

   - build - will build containers in the order in which they were passed
   - clone - Will clone repos, or update local repos and then build in the order in
     which they were passed.
   - pull - Will pull images from the Docker Hub.

   Then optionally start the cluster via docker-compose.


 - framework [chronos|marathon]
    - chronos [post|del] - POST or DELETE jobs from chronos.
    - marathon [post|put|del] -POST's, PUT's, or DELETE's apps from marathon.

- stop - Brings down the mesos containers.

 - up - Brings up the mesos containers.
EOF
}

usage_host() {
cat <<EOF
Usage: thegrid.sh host [bootstrap|clean|framework|network|ovpn|stop|up]

 - bootstrap [build|clone|pull] <containers> -- NOTE: requires root (sudo)
   Defaults to the following containers:
   [ubuntu-base,mesos-base,mesos-master,mesos-slave,mesos-slave-jenkins]
   [mesos-dns,zookeeper,marathon,chronos,bamboo,openvpn,jenkins,jenkins-build-base]

   - build - will build containers in the order in which they were passed
   - clone - Will clone repos, or update local repos and then build in the order in
     which they were passed.
   - pull - Will pull images from the Docker Hub.

   Then perform the following actions:

    * Create the mesos network (mesos0 192.168.111.0/24)
    * Create Service Network and IPs for the  Mesos Services (192.168.111.10-16)
    * Generate OpenVPN certs and a generic client config.
    * Modify Marathon app definitions with information gathered during bootstrapping.
    * Optionally start the cluster via docker-compose.

- clean - Removes mesos0 bridge and cleans up volumes.

 - framework [chronos|marathon]
    - chronos [post|del] - POST or DELETE jobs from chronos.
    - marathon [post|put|del] -POST's, PUT's, or  DELETE's apps from marathon.

 - network [bridge|init|ip] -- NOTE: requires root (sudo)
    - bridge [create|del] - creates or destroys the mesos0 bridge
    - init - creates the mesos0 bridge and service ips.
    - ip [add|del] add or delete ips associated with the mesos0 bridge.

 - ovpn - Configures OpenVPN certificates and container. --Note: requires root (sudo)

 - stop - Brings down the mesos containers.

 - up - Brings up the mesos containers.
EOF

}

usage_framework() {
cat <<EOF
Usage: thegrid.sh [host|container] framework [marathon|chronos] [post|put|del] <app/job name>

Marathon app files must be [name].[host|container].marathon.local.json e.g.

ovpn.host.marathon.local.json

Chronos job files must be [name].chronos.local.json e.g.

test_job.chronos.local.json
EOF
}

usage_network() {
cat <<EOF
Note: Requires root (sudo)

Usage: thegrid.sh host network [init|bridge|ip]
 - init - Initializes the mesos0 bridge and service ips.

 - bridge [create|del] - Creates or deletes the mesos0 bridge

 - ip [add|del] 
   - add <ip> <label> - The ip should be in the 192.168.111.0/24 range, and the label will be
     prepended with "mesos0:"
   - del <ip|label> - Deletes the ip either by ip or the label.
EOF
}

usage_main() {
cat <<EOF
Usage: thegrid [build|clone|container|host|pull]

 - build <containers> - Takes a comma delimited list of directories in the containers directory, builds 
   them, and names them the same as their folder. Defaults to:
    [ubuntu-base,mesos-base,mesos-master,mesos-slave,mesos-slave-jenkins]
    [mesos-dns,zookeeper,marathon,chronos,bamboo,openvpn,jenkins,jenkins-build-base]

 - clone <containers> - Takes a comma delimited list of git projects hosted by mrbobbytables and clones
   or pulls updated versions into the containers directory. Defaults to:
    [ubuntu-base,mesos-base,mesos-master,mesos-slave,mesos-slave-jenkins]
    [mesos-dns,zookeeper,marathon,chronos,bamboo,openvpn,jenkins,jenkins-build-base]

 - container - Cluster brought up with strictly docker private networking. It has very limited functionality.
   Useful as a quick testing of marathon/chronos.

 - host - Requires root privs (sudo), but creates a mock mesos network and attaches the services to it.
   This will allow for services such as OpenVPN, Bamboo, and Mesos-DNS to function in a mock a production
   deoplyment.

 - pull <containers> Takes a comma delimited list of containers and pulls them from the dockerhub.
   Defaults to:
    [ubuntu-base,mesos-base,mesos-master,mesos-slave,mesos-slave-jenkins]
    [mesos-dns,zookeeper,marathon,chronos,bamboo,openvpn,jenkins,jenkins-build-base]
EOF
}


main() {
  case "${1,,}" in
    build) build_containers "$2" ;;
##############################
    clone) clone_containers "$2" ;;
##############################
    container)
      case "${2,,}" in
#####--------------------------
        bootstrap)
          check_compose
          mkdir -p local/containers
          mkdir -p local/marathon_apps
          mkdir -p local/chronos_jobs
          cp -p marathon_templates/* local/marathon_apps
          cp -p chronos_templates/* local/chronos_jobs
          local container_list=""
          container_list="ubuntu-base,mesos-base,mesos-master,mesos-slave,zookeeper,marathon,chronos"
          if [[ $# -eq 4 ]]; then
            container_list="$4"
          fi
          if [[ $# -ge 3 ]]; then
            case "$3" in
              clone) 
                clone_containers "$container_list"
                build_containers "$container_list"
              ;;
              pull) pull_containers "$container_list" ;;
              build|*) build_containers "$container_list" ;;
            esac
          else
            clone_containers "$container_list"
            build_containers "$container_list"
          fi

          echo "Please start the cluster to finish customization of the marathon configs. It cannot be done while the containers are not running."
          start_cluster "container"
        ;;
#####--------------------------
        framework)
          if [[ $# -eq 5 ]]; then
            case "$3" in
              marathon)
                case "$4" in
                  del) del_marathon "$5" ;;
                  post) post_marathon "$5" ;;
	          put) put_marathon "$5" ;;
                  *) usage_framework ;;
                esac
              ;;
              chronos)
                if [[ $# -eq 5 ]]; then
                  case "$4" in
                    del) del_chronos "$5" ;;
                    post) post_chronos "$5" ;;
                    *) usage_framework ;;
                   esac
                fi
              ;;
            esac
          else
            usage_framework
          fi
        ;;
#####--------------------------
        stop) stop_cluster ;;
#####--------------------------
        up) start_cluster "container" ;;
#####--------------------------
        *) usage_container ;;
#####--------------------------
      esac
    ;;
###############################
    host)
      case "${2,,}" in
#####--------------------------  
        bootstrap)
          host_check_prereq
          check_compose
          mkdir -p local/containers
          mkdir -p local/marathon_apps
          mkdir -p local/chronos_jobs
          cp -p marathon_templates/* local/marathon_apps
          cp -p chronos_templates/* local/chronos_jobs
          if [[ $# -ge 3 ]]; then
            case "$3" in
              clone)
                clone_containers "$4"
                build_containers "$4"
              ;;
              pull) pull_containers "$4" ;;
              build|*) build_containers "$4" ;;
            esac
          else
            clone_containers
            build_containers
          fi
          get_host_ip
          read -p "Configure OpenVPN? (Y/N) [Default: Y]" cnf_ovpn
          cnf_ovpn=${cnf_ovpn:-y}
          if [[ "${cnf_ovpn,,}" == "y" || "${cnf_ovpn,,}" == "yes" ]]; then
            host_config_ovpn
          fi
          host_create_bridge
          host_create_service_ips
          if [[ -d containers/ ]]; then
            chown -R "$SUDO_USER:$SUDO_USER" containers/
          fi
          chown -R "$SUDO_USER:$SUDO_USER" local/
          start_cluster "host"
        ;;
#####--------------------------
        clean)
          host_check_prereq
          stop_cluster
          host_del_bridge
          if [[ -d /var/lib/mesos ]]; then
            echo "Removed volume: /var/lib/mesos"
            rm -r /var/lib/mesos
          fi
          if [[ -d /mnt/mesos/sandbox ]]; then
            echo "Removed volume: /mnt/mesos/sandbox"
            rm -r /mnt/mesos/sandbox
          fi
          if [[ -d /tmp/registry ]]; then
            echo "Removed volume: /tmp/registry"
            rm -r /tmp/registry
          fi
        ;;
#####--------------------------
        framework)
          if [[ $# -eq 5 ]]; then
            case "$3" in
              marathon)
                case "$4" in
                  del) del_marathon "192.168.111.12" "$5" ;;
                  post) post_marathon "192.168.111.12" "$5" ;;
	          put) put_marathon "192.168.111.12" "$5" ;;
                  *) usage_framework ;;
                esac
              ;;
              chronos)
                case "$4" in
                  del) del_chronos "192.168.111.13" "$5" ;;
                  post) post_chronos "192.168.111.13" "$5" ;;
                  *) usage_framework ;;
                esac
              ;;
            esac
          else
            usage_framework
          fi
        ;;
        ovpn)
          host_check_prereq
          get_host_ip
          host_config_ovpn
        ;;
#####--------------------------
        network)
          if [[ $# -ge 3 ]]; then
            case "${3,,}" in
              bridge)
                if [[ $# -eq 4 ]]; then
                  case "$4" in
                    create) 
                      host_check_prereq
                      host_create_bridge
                    ;;
                    del)
                      host_check_prereq 
                      host_del_bridge
                    ;;
                  esac
                fi
              ;;
              init)
                host_check_prereq
                host_create_bridge
                host_create_service_ips
              ;;
              ip)
                if [[ $# -ge 5 ]]; then
                  case "$4" in
                    add)
                      if [[ $# -eq 6 ]]; then
                        host_check_prereq
                        host_add_mesos0_ip "$5" "$6"
                      else
                        echo "Usage: thegrid.sh host network ip add <ip> <label>"
                      fi
                    ;;
                    del)
                      if [[ $# -eq 5 ]]; then
                        host_check_prereq 
                        host_del_mesos0_ip "$5"
                      else
                        echo "Usage: thegrid.sh host network ip del <ip|label>"
                      fi
                    ;;
                  esac
                fi
              ;;
              *)
                usage_network
              ;;
            esac
          fi
        ;;
#####--------------------------
        stop) stop_cluster ;;
#####--------------------------
        up) start_cluster "host" ;;
#####--------------------------
        *) usage_host ;;
#####--------------------------
      esac
    ;;
##############################
    pull) pull_containers "$2" ;;
##############################
    *) usage_main ;;
  esac
}

main "$@"
