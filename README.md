# - TheGrid -

A helpful little bash script and collection of app/tasks definitions for Marathon, Chronos, and Jenkins. Useful for quickly testing and dev'ing a Mesos-stack locally.

---

### Index

* [tl;dr](#tldr)
* [Tutorial (the non tl;dr version)](#tutorial)
* [Notes and Tips](#notes-and-tips)
 * [caveats](#caveats)
* [Quick Reference](#quick-reference)
* [Command Referece](#command-reference)
 * [general](#general)
 * [host](#host-specific)
 * [host-networking](#host-networking)
 * [container](#container-specific)
 * [framework](#framework-usage)




---
---
### tl;dr

Want to get up and going as fast as possible? Do the following:

##### Before you begin

 * For this demo, a vagrant image is provided, and the instructions will assume it is to be used. If you wish to execute everything without vagrant; please consider the following:

 * VM spec wise, more than 2 cores is ideal along with 2gbs of ram. It can function with 2 core, but resource scheduling may wind up queueing some tasks towards the end of the demo.

 * Ensure you have docker, docker-compose, and bridge-utils installed. If you are on a debian based distro; this should be all that is required.

* If using **RHEL/cent/fedora** -- do the following first (**IF A VANILLA SYSTEM**):
 * Install a version of docker that is **remote API** compatible with the version used in the `mrbobbytables/mesos-slave` and `mrbobbytables/jenkins-build-base` containers.
 * Add an entry to your hostfile (`/etc/hosts`) that maps `127.0.1.1` to your hostname.
 * `sudo iptables --flush` unless you have your own rules in there..in which case you're on your own.


---


1. Clone this repo
2. Install the salt plugin with - `vagrant plugin install vagrant-salt`
3. Bring up the vagrant image - `vagrant up`
4. Once up and running, `vagrant ssh` and switch to the `/vagrant` directory.
5. `sudo ./thegrid.sh host bootstrap pull`
  * pulls images
  * creates mesos0 bridge and container IPs
  * creates openvpn config. **Note:** Follow the directions, and generate a server cert and a client cert. The prompts do change for client cert gen and you can't just enter through it all. Client config for importing will be at `local/client-<public_ip>.ovpn`. If you make a mistake, you can regen it after the fact with `sudo ./thegrid.sh host ovpn`
  * creates a customized docker-compose.yml file.
  * starts cluster (if not started, start with `./thegrid.sh host up` or `docker-compose up -d`)
6. Once Marathon is up and running execute the following:
  * `./thegrid.sh host framework marathon post mesos-dns`
  * `./thegrid.sh host framework marathon post ovpn` (if config was made)
  * `./thegrid.sh host framework marathon post bamboo`
7. If you did create an OpenVPN container, now would be the time to connect. The below should be available
  * Mesos-master: `192.168.111.11:5050`
  * Marathon: `192.168.111.12:8080`
  * Chronos: `192.168.111.13:4400`
  * Jenkins: `192.168.111.14:8888`
  * Bamboo: `192.168.111.16:8000`

**Tip:** Keep a tab open with the mesos master to see all the jobs going up and down as you do them

##### Want to schedule a cron job with Chronos?

1. `./thegrid.sh host framework chronos post test`
2. Connect to Chronos (`192.168.111.13:4400`)
3. You should see a job called `test`. Select it and in the new menu that pops up press the `Force Run` button. It looks like a play button. If successful, the UI will update with the `LAST` column showing `SUCCESS`


##### Want to test Bamboo?

1. `./thegrid.sh host framework marathon post nginx`
2. Connect to Bamboo's management page (`192.168.111.16:8000`)
3. Change the ACL rule for nginx to `path_beg -i /`
4. Connect to the public facing IP of your slave on port 80. It should now be the default nginx page.
5. When done kill nginx by executing `./thegrid.sh host framework marathon del nginx`.
6. Refresh the Bamboo UI and it should be gone.

##### Want to test Jenkins?

1. Connect to Jenkins (`192.168.111.14:8888`)
2. Goto `Manage Jenkins` -> `Configure System` and change a setting. I like to disable sshd. Then save. If you don't, you're going to have a bad time and an NPE error will be thrown.
3. Click on `New Item` and create a new `Freestyle project`. Call it whatever you want.
4. Set `Label Expression` to `mesos`.
5. Go down to build and add an `Execute Shell` build step; and give it some command to execute. An example could be something like `echo "look ma, I scheduled!`. Then save the job.
6. Once saved, hit `Build Now`. You should see it add an offline slave, the offline slave will then be brought online and the job will run.
7. To verify, in the `Build History`, click on the run # (should be 1). Then click on `Console Output`. You should see the output from the executed command.

##### Want to do something worthwhile with Jenkins?

Lets build a container that can be used to push things to marathon.

1. First, an insecure registry entry needs to be added to your docker init. This should be `--insecure-registry registry.marathon.mesos:31111` This is different for Ubuntu-upstart (14.04), Ubuntu-systemd(15.04), and different on other distros. Google is your friend here. I'll give a quick list below:
 * Ubuntu 14.04 - `/etc/default/docker` - `DOCKER_OPTS`
 * Ubuntu 15.04 - `/etc/systemd/system/multi-user.target.wants/docker.service` - `ExecStart`
 * More Info: [Configuring and Running Docker](https://docs.docker.com/articles/configuring/)
2. Once added, restart the docker daemon. If Mesos is running execute `./thegrid.sh host stop` to bring things down gracefully, or just stop them and recreate them. It's not a big deal.
3. `./thegrid.sh host framework marathon post registry` **Note:** the registry volume will be mounted from `/tmp/registry` from the host.
4. In Jenkins; if this is your first time doing something -- execute step 2 from **'Want to test Jenkins?'** first. Otherwise click on `New Item` and create a new `Freestyle project`. Call it build-curl-slave; or whatever you want.
5. Set the `Label Expression` to `mesos-docker`.
6. Go down to build and add an `Execute Shell` build step. With something similar to the following:
```
touch Dockerfile
echo "FROM mrbobbytables/jenkins-build-base" >> Dockerfile
echo "RUN apt-get update && apt-get -y install curl && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*" >> Dockerfile
docker build -t registry.marathon.mesos:31111/curl-slave .
docker push registry.marathon.mesos:31111/curl-slave
```
7. To verify, in the `Build History`, click on the run # (should be 1). Then click on `Console Output`. You should see the output from the executed command.
8. To doubly verify, from the host execute `docker rmi registry.marathon.mesos:31111/curl-slave` and then do a pull `docker pull registry.marathon.mesos:31111/curl-slave`. It should be downloaded from the registry hosted in mesos.
9. Back in Jenkins, go back to `Manage Jenkins` -> `Configure System`, and scroll down to the `Cloud` section.
10. Under `Mesos Cloud`, click on `Advanced...`, then scroll down further and click on `Add Slave Info`.
11. Set the label string to `mesos-docker-curl`, and click on the `Advanced...` button.
12. Check `Use Docker Containerizer`, and specify `registry.marathon.mesos:31111/curl-slave` for the `Docker Image`.
13. Click on `Add Volume` and specify `/var/run/docker.sock` for both the `Container Path` and `Host Path`. If on an Ubuntu host, add another volume with `/usr/bin/docker` for both paths, and mark it as read only.
14. Click on `Add Parameter` and for the parameter key, specify `dns` and for the value, use `192.168.111.15` (the mesos-dns instance).
15. Click `save`, and the new slave should be ready for use.


##### Let's tie it all together now~!

We're going to build a container and have jenkins trigger marathon to spin it up.

1. Click on `New Item` and create a new `Freestyle project`. Call it `nginx-jm` (for nginx-jenkins-mesos).
2. For label set it to `mesos-docker-curl` (what we configured in **`Want to do something worthwhile with Jenkins?`**).
3. Add a new `Execute Shell` Build step and use the following:
```
git clone https://github.com/mrbobbytables/nginx-jenkins-marathon-test.git
echo ${BUILD_NUMBER} > nginx-jenkins-marathon-test/skel/build
docker build -t registry.marathon.mesos:31111/nginx-jm nginx-jenkins-marathon-test/
docker tag registry.marathon.mesos:31111/nginx-jm registry.marathon.mesos:31111/nginx-jm:${BUILD_NUMBER}
docker push registry.marathon.mesos:31111/nginx-jm
```
4. Then add a 2nd `Execute Shell` build step with this:
```
sed -i -e "s|registry.marathon.mesos:31111/nginx-jm:latest|registry.marathon.mesos:31111/nginx-jm:$BUILD_NUMBER|g" \
    nginx-jenkins-marathon-test/nginx-jm.host.marathon.local.json
curl -X PUT -H "Accept: application/json" -H "Content-Type: application/json" \
http://192.168.111.12:8080/v2/apps/nginx-jm -d @nginx-jenkins-marathon-test/nginx-jm.host.marathon.local.json
```
This will pull down the repo, inject the jenkins build number into the build file, and build/push the container. If it successfully builds the container, it will update the marathon app definition in `nginx-jenkins-marathon-test/nginx-jm.host.marathon.local.json` and send it to marathon via a `PUT` request.

5. At this point pop on over to Bamboo (`192.168.111.16:8000`) and delete the `/nginx` rule (if it's still there from earlier), and change the rule for `/nginx-jm` to `path_beg -i /`
6. Pop on over to your public IP, and you should see a small page displaying the container ID and build # from jenkins.
7. Now that everything is tied together, pop open new tabs for marathon (`192.168.111.12:8080`), and jenkins (`192.168.111.14:8888`). In jenkins, trigger a new build for `nginx-jm`. Then switch over to marathon. You should see the health bar for the `/nginx-jm` app become a mix of green, grey, and blue. Marathon is executing the upgrade strategy specified in the marathon app definition. It will spin up a new node on the new build expanding the total instances of `nginx-jm` to 3, then phase out one of the old instances. It will do this for all of them. Back on the public facing ip, you should see instances with new container IDs and build numbers.


##### Let's roll it back

1. In marathon (`192.168.111.12:8080`), click `/nginx-jm` and then click on `configuration`.
2. If you scroll down, you should see a list of date/timestamps. These are the previous versions that marathon has executed.
3. Click on `Apply these settings`. Marathon will then roll back to that version of the deployment.
4. Pop on over to the public IP and you should start to see the old build number appear after a few refreshes.



##### This completes the tl;dr.
Wound up being a bit more than a tl;dr...


##### How do I return my system to normal?
`./thegrid.sh host stop`
`sudo ./thegrid.sh host clean`




---

---
---


### Tutorial

Before even starting the bootstrap process; if you are **NOT** going to use the vagrant image and are on a RHEL/cent/fedora system, please do the following first:
 * Install a version of docker that is **remote API** compatible with the version used in the `mrbobbytables/mesos-slave` and `mrbobbytables/jenkins-build-base` containers.
 * Add an entry to your hostfile (`/etc/hosts`) that maps `127.0.1.1` to your hostname.
 * `sudo iptables --flush` unless you have your own rules and are comfortable modifying them manually.


##### Bootstrapping

**Note: If using Vagrant**
Before you bootstrap, please install the `vagrant-salt` plugin. Once installed, you may `vagrant up` and then `vagrant ssh`. For the rest of this tutorial, assume working out of the `/vagrant` directory within the vm.

---

There are two available paths to bootstrapping: `host` and `container`. `host` is the preferred method, but it requires sudo and bridge utils to create a 'mock' private Mesos Network with a bridge. All containers should function as intended with a few caveats in `host` mode and the bridge can be removed, or will automatically be removed upon restart.

`container` mode is bare bones - Mesos / Marathon / Chronos will mostly work. Items can be scheduled, but IPs should be substituted in Marathon for the public facing IP of the host.

To quickly get up and going in `host` mode, execute the following:
`sudo ./thegrid.sh host bootstrap pull`

or, if you'd prefer to clone the container repos and build them locally:
`sudo ./thegrid.sh host bootstrap clone`

In either case, after going through the bootstrap process a directory will be created in the project root called `local`. This will contain all customized configs and containers (certs for OpenVPN, modified marathon templates etc). If you choose to build the OpenVPN container, the client configuration should be found in the `local` directory and titled `client-<public-ip>.ovpn`. **Note:** If you're running this on your main OS and not a virtual machine sitting on top of it, OpenVPN can be disregarded and skipped.


Once downloading/building is complete it will then create the `mesos0` bridge network with static IPs designated to their associated service. For a full list of assignments execute `ip addr show mesos0`. Each service will have an associated IP and label. e.g. `mesos0:jenkins` etc.

After the bridge network has been started, it will then ask you if you wish to start the cluster. Either select yes, or start it after the fact with `docker-compose up -d`.


---

##### Connecting to the Services

If you bootstrapped it on another host (VM), be sure to install an OpenVPN client (e.g. [tunnelblick for OSX](https://tunnelblick.net/)) on the connecting system and import the generated client config (located at `local/client-<public-ip>.ovpn`) that was produced during bootstrapping.

After that start the services with:

`./thegrid.sh host framework marathon post mesos-dns`
`./thegrid.sh host framework marathon post ovpn`

This will start mesos-dns and OpenVPN. FYI -- The above commands are simply curl commands under the hood that hit the [Marathon REST API](https://mesosphere.github.io/marathon/docs/rest-api.html).

Once connected, you should be able to use the following services:
 - `192.168.111.11:5050` - Mesos Master
 - `192.168.111.12:8080` - Marathon
 - `192.168.111.13:4400` - Chronos
 - `192.168.111.14:8888` - Jenkins

---

##### Using Marathon and Chronos

For demo purposes, a small variety of service and job configs are already available. For marathon, this includes - mesos-dns, openvpn, bamboo, nginx, and the docker registry. For Chronos, a single test is provided, simply called - test.

The basic http post/put/delete commands are wrapped within the script; and usage is as follows.

`<./thegrid.sh <host|container> framework <marathon|chronos> <post|put|del> <name>`

**Note:** Chronos does not have the put method enabled with this script.

The name at the end maps to files stored in `local/marathon_apps` and `local/chronos_jobs` and follow the format of:

`<name>.<host|container>.marathon.local.json`

and

`<name>.chronos.local.json`

You can add your own within those directories as long as you adhere to the naming scheme.; but if you decide to move forward with Marathon and Chronos - I **HIGHLY** recommend learning the curl commands or using some other tool to interact with their REST APIs.

---

##### Using Chronos

For demo purposes, there is only a single test job available for Chronos.

First post the test job th chronos:

`./thegrid.sh host framework chronos post test`

Then connect to the chronos web interface on `192.168.111.13:4400`.

You should see a single job listed called `test`. Click on it to open the job settings panel on the right hand side.

Click the `Force Run` button (icon 2nd from the left) to execute an on demand task.

Once complete; the `LAST SUCCESS` time should be updated and `SUCCESS` should be listed in job list panel.

To see the job output, goto the mesos master (`192.168.111.11:5050`) and click on the completed Chronos task's `sandbox` link. Then click on `stdout`. You should see something similar to the following:
```
Starting task ct:1443881700000:0:test:
lookma, i'm scheduled!
```


---

##### Using Bamboo

Bamboo's usage in a local deployment fairly minimal -- If no custom HAproxy configs are to be provided, getting up and going is quite quick.

If not already started, execute this command to spawn an instance of Bamboo.

`./thegrid.sh host framework marathon post bamboo`

Once up, connect to the local web server for Bamboo (`http://192.168.111.16:8000`).

From there, modify the application rules as needed.

For a quick test with the nginx container; first submit it to marathon with:

`./thegrid.sh host framework marathon post nginx`

Then in the Bamboo interface, modify the ACL entry for nginx to be `path_beg -i /`. If you are unfamiliar with HAproxy, this tells it to route any traffic to the nginx container(s) that begins with the prefix `/`. So **ALL** traffic will route to nginx when coming in on the default port 80.

You can verify simply by going to your `http://<public_ip>/`


For any advanced configuration. The HAproxy template should be modified before the Bamboo container is built, or have it supplied at runtime through a volume mount or seeded via some method with `ENVIRONMENT_INIT`.


---

##### Using Jenkins

After services have started, connect to `http://192.168.111.14:8888`. Before any jobs can be scheduled, a small configuration change is required. Go to `Manage Jenkins` -> `Configure System` and change a benign setting such as `Quiet Period` or disable the `SSHD` port; and save your changes. After doing so, the Jenkins config will update and items can be scheduled in Mesos without issue. Please note; this behavior is **ONLY** present in new unconfigured servers and would never crop up in a production setting.

With Jenkins configured, jobs may now be added.

By default, there are two available build container labels. `mesos` is a vanilla instance of the [mrbobbytables/jenkins-build-base](https://github.com/mrbobbytables/jenkins-build-base) container and is suitable for quick testing like echoing output. The other `mesos-docker` is the same container, but with `/usr/bin/docker` and `/var/run/docker.sock` mounted. This container is suitable for building other containers.

To test simple execution, create a new `Freestyle project` job. At the job configuration page, set the label to `mesos`, and then add a new `Execute Shell` Build Step. Simply put something like:

```
echo "this job ran on Mesos"
```

Then save the job and press `Build Now`.

You'll see a new Mesos-slave added (it will start as offline), and the job will then execute on it.

To verify the job - click on the run number (should be #1) in the `Build History` on the left hand side. Then click on `Console Output`. You should see the output from the executed command.

**Building containers**

To test building and pushing containers, there is a prerequisite that requires changing the docker daemon settings of the host to allow the insecure registry.

Modifying the docker daemon settings is rather host specific [Docker's docs cover it quite well](https://docs.docker.com/articles/configuring/), but for a quick (Ubuntu) reference -- please see the below list:

 * Ubuntu 14.04 - `/etc/default/docker` - `DOCKER_OPTS`
 * Ubuntu 15.04 - `/etc/systemd/system/multi-user.target.wants/docker.service` - `ExecStart`

All that must be added is `--insecure-registry registry.marathon.mesos:31111` and restart the docker daemon.

1. With that done, bring up the cluster (`docker-compose up -d` or `./thegrid.sh host up`) and push the registry to marathon with

`./thegrid.sh host framework marathon post registry`

2. After the registry is up. Add a new build job to Jenkins, and remember -- if this is the first time this instance of Jenkins has been run, a config **MUST** be changed under `Configure System`.

4. Create a new build job, and set it up similarly to the previous job (`Freestyle projeft`) but for the label use `mesos-docker`, and set the `Execute Shell` Build Step to the following:
```
touch Dockerfile
echo "FROM mrbobbytables/jenkins-build-base" >> Dockerfile
echo "RUN apt-get update && apt-get -y install curl && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*" >> Dockerfile
docker build -t registry.marathon.mesos:31111/curl-slave .
docker push registry.marathon.mesos:31111/curl-slave
```

5. Save the job, and click `Build Now`.

6. Once the build is completed, you can verify it's success on the host by wiping the curl slave image and pulling it from the registry:
```
docker rmi registry.marathon.mesos:31111/curl-slave
docker pull registry.marathon.mesos:31111/curl-slave
```

**Pushing containers to Mesos with Marathon**

This takes advantage of the new build slave built in the previous exercise. Before you begin, this must be added as a new slave in the Jenkins Mesos Cloud config.

1. Go back to `Manage Jenkins` -> `Configure System`, and scroll down to the `Cloud` section.

2. Under `Mesos Cloud`, click on `Advanced...`, then scroll down further and click on `Add Slave Info`.

3. Set the label string to `mesos-docker-curl`, and click on the `Advanced...` button.

4. Check `Use Docker Containerizer`, and specify `registry.marathon.mesos:31111/curl-slave` for the `Docker Image`.

5. Click on `Add Volume` and specify `/var/run/docker.sock` for both the `Container Path` and `Host Path`. If on an Ubuntu host, add another volume with `/usr/bin/docker` for both paths, and mark it as read only.

6. Click on `Add Parameter` and for the parameter key, specify `dns` and for the value, use `192.168.111.15` (the mesos-dns instance).

7. Click `save`, and the new slave should be ready for use.

8. Scroll back up and click on `New Item`. Then create a new `Freestyle project`, and call it `nginx-jm` (for nginx-jenkins-mesos).

9. For label set it to `mesos-docker-curl` (what was defined in step 3).

10. Add a new `Execute Shell` Build step and use the following:
```
git clone https://github.com/mrbobbytables/nginx-jenkins-marathon-test.git
echo ${BUILD_NUMBER} > nginx-jenkins-marathon-test/skel/build
docker build -t registry.marathon.mesos:31111/nginx-jm nginx-jenkins-marathon-test/
docker tag registry.marathon.mesos:31111/nginx-jm registry.marathon.mesos:31111/nginx-jm:${BUILD_NUMBER}
docker push registry.marathon.mesos:31111/nginx-jm
```

11. Then add a 2nd `Execute Shell` build step with this:
```
sed -i -e "s|registry.marathon.mesos:31111/nginx-jm:latest|registry.marathon.mesos:31111/nginx-jm:$BUILD_NUMBER|g" \
    nginx-jenkins-marathon-test/nginx-jm.host.marathon.local.json
curl -X PUT -H "Accept: application/json" -H "Content-Type: application/json" \
http://192.168.111.12:8080/v2/apps/nginx-jm -d @nginx-jenkins-marathon-test/nginx-jm.host.marathon.local.json
```
This will pull down the repo, inject the jenkins build number into the build file, and build/push the container. If it successfully builds the container, it will update the marathon app definition in `nginx-jenkins-marathon-test/nginx-jm.host.marathon.local.json` and send it to marathon via a `PUT` request.

12. Save the job and click `Build Now`.

13. At this stage, if you wish you can watch it complete and push the build or proceed onto the next step.

14. Open the Bamboo config page (`192.168.111.16:8000`) and delete the `/nginx` rule. If you're still running the `/nginx` marathon app, I'd delete it as it is no longer required at this point. Once the rule is deleted and `/nginx-jm` has started to deploy, modify `/nginx-jm`'s rule to be `path_beg -i /`.

15. Open a page and point it to your public IP. You should see a small page displaying the container ID and build # from jenkins, and if you refresh it a few times -- you should see multiple container ID's. HAproxy is round-robin load balancing between them.

16. Now that everything is tied together, open a new browser tab for marathon (`192.168.111.12:8080`), jenkins (`192.168.111.14:8888`), and your public IP. Then, in jenkins, trigger a new build for `nginx-jm` and switch back to Marathon. You should see the health bar for the `/nginx-jm` app become a mix of green, grey, and blue. Marathon is executing the upgrade strategy specified in the marathon app definition. It will deploy a new node on the new build expanding the total instances of `nginx-jm` to 3, then phase out one of the old instances. It will do this for all of them.

17. Switch to the tab with your public IP, and start to refresh the page. You should see instances with new container IDs and build numbers until all instances are safely on the new build.


**Rolling back a deployment**

In an instance where something was pushes live that shouldn't have been and you need to rollback, Marathon has a very way of executing this.

1. In marathon (`192.168.111.12:8080`), click `/nginx-jm` and then click on `configuration`.

2. Scroll down and you should see a list of date/timestamps. These are all the previous versions of that marathon app definition that have been executed.

3. Click on an older one and then press `Apply these settings`. Marathon will then roll back to that version of the deployment in the same fashion that it was deployed. -- Adding a new instance on the old build, removing an older instance and so on.

4. Go back to your public facing IP, and press refresh a few times. You should see instances with the new container IDs and the build number of the version you selected in the step 3.

---

**Note:**
When done testing, be sure to remove the insecure registry entry from your docker daemon settings.

---
---

### Notes and Tips

* If you have restarted your system, remember to re-crate the mesos0 bridge with `./thegrid.sh host network init`

* Clean your system of anything created/mounted during use with `./thegrid.sh host clean`

##### Caveats

* In a production multi-host environment Mesos frameworks can be scheduled on a Mesos-slave. When doing it locally (at least under Mesos 0.23.0) it will encounter issues scheduling.


---
---


### Quick Reference

---

##### Requirements:
* [Docker](https://docs.docker.com/installation/)
* [Docker-compose](https://docs.docker.com/compose/install/)
* Bridge-utils (if using host networking)

---

##### Containers:

 - [mrbobbytables/ubuntu-base](https://github.com/mrbobbytables/ubuntu-base) - Base image. Contains helper functions, scripts, logstash-forwarder and supervisord.
 - [mrbobbytables/mesos-base](https://github.com/mrbobbytables/mesos-base) - Base Mesos image. Services as root for downstream Mesos images.
 - [mrbobbytables/zookeeper](https://github.com/mrbobbytables/zookeeper) - Zookeeper - Cluster state maintainer.
 - [mrbobbytables/mesos-master](https://github.com/mrbobbytables/mesos-master) - Mesos Master, coordinator for the cluster.
 - [mrbobbytables/mesos-slave](https://github.com/mrbobbytables/mesos-slave) - Mesos slave with Docker packaged within it.
 - [mrbobbytables/mesos-slave-jenkins](https://github.com/mrbobbytables/mesos-slave-jenkins) - Mesos slave with jenkins user.
 - [mrbobbytables/mesos-dns](https://github.com/mrbobbytables/mesos-dns) - DNS service discovery for systems registered with Mesos.
 - [mrbobbytables/marathon](https://github.com/mrbobbytables/marathon) - cluster wide 'init' system.
 - [mrbobbytables/chronos](https://github.com/mrbobbytables/chronos) - Distributed cron framework.
 - [mrbobbytables/jenkins](https://github.com/mrbobbytables/jenkins) - Jenkins CI server with Mesos Integration
 - [mrbobbytables/jenkins-build-base](https://github.com/mrbobbytables/jenkins-build-base) - Base jenkins build image.
 - [mrbobbytables/bamboo](https://github.com/mrbobbytables/bamboo) - Service Discovery and routing (HAproxy) for Marathon scheduled tasks.

---

##### Marathon Apps

**Host:**
* bamboo
* mesos-dns
* ovpn
* registry
* nginx
* nginx-jm (must be created first)

**Container:**
* nginx

---

##### Chronos
* test

---


##### Addresses and DNS Names

**Bridge Name:** mesos0

**Note:** Containers spun up via marathon that have host networking will resolve to the slave IP (as expected). However there will be no srv records reporting the ports they're open on. This is not an issue in production.


| Container               | IP                                   | Connection label  | Port(s)                   | DNS                        |
|-------------------------|--------------------------------------|-------------------|---------------------------|----------------------------|
| `zookeeper`             | `192.168.111.10`                     | `mesos0:zk`       | `2181,2888,3888`          |                            |
| `mesosmaster`           | `192.168.111.11`                     | `mesos0:master`   | `5050,9000`               | `master.mesos`             |
| `mesosslave`            | `<public facing ip>`                 | `<none>`          | `5051,9100`               |                            |
| `marathon`              | `192.168.111.12`                     | `mesos0:marathon` | `8080,9200`               |                            |
| `chronos`               | `192.168.111.13`                     | `mesos0:chronos`  | `4400,9300`               |                            |
| `jenkins`               | `192.168.111.14`                     | `mesos0:jenkins`  | `8888,9400`               |                            |
| `mesos-dns`             | `192.168.111.15`                     | `mesos0:dns`      | `53,8123`                 | `mesos-dns.marathon.mesos` |
| `bamboo`                | `<public facing ip>, 192.168.111.16` | `mesos0:bamboo`   | `80,8000`                 | `bamboo.marathon.mesos`    |
| `openvpn`               | `<public facing ip>, 192.168.111.17` | `mesos0:ovpn`     | `1194`                    | `ovpn.marathon.mesos`      |
| `distribution/registry` | `<docker0 network>`                  |                   | `31111`                   | `registry.marathon.mesos`  |
| `library/nginx`         | `<docker0 network>`                  |                   | `<port from mesos range>` | `nginx.marathon.mesos`     |
| `nginx-jm`              | `<docker0 network>`                  |                   | `<port from mesos range>` | `nginx-jm.marathon.mesos`  |

**NOTE:** All dns names excluding `master.mesos` will resolve to the public IP.


---
---

### Command Reference

---

##### General

```
bob@derp:/data/grid$ ./thegrid.sh --help
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
    
```

---

##### Host Specific

```
bob@derp:/data/grid$ ./thegrid.sh host --help
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
```

##### Host Networking

```
bob@derp:/data/grid$ ./thegrid.sh host network --help
Note: Requires root (sudo)

Usage: thegrid.sh host network [init|bridge|ip]
 - init - Initializes the mesos0 bridge and service ips.

 - bridge [create|del] - Creates or deletes the mesos0 bridge

 - ip [add|del]
   - add <ip> <label> - The ip should be in the 192.168.111.0/24 range, and the label will be
     prepended with "mesos0:"
   - del <ip|label> - Deletes the ip either by ip or the label.

```

---

##### Container Specific

```
bob@derp:/data/public/grid2/grid$ ./thegrid.sh container --help
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

```

---

##### Framework Usage

```
bob@derp:/data/grid$ ./thegrid.sh host framework --help
Usage: thegrid.sh [host|container] framework [marathon|chronos] [post|put|del] <app/job name>

Marathon app files must be [name].[host|container].marathon.local.json e.g.

ovpn.host.marathon.local.json

Chronos job files must be [name].chronos.local.json e.g.

test_job.chronos.local.json

```


