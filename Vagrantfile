# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "mesos"
  config.vm.network "private_network", ip: "192.168.99.10"
  config.vm.synced_folder "salt/roots", "/srv/"
  config.vm.synced_folder "salt/minion.d/", "/etc/salt/minion.d/"


  config.vm.provider "virtualbox" do |vb|
     vb.cpus = 3
     vb.memory = "3072"
   end

  config.vm.provision :salt do |salt|
    salt.verbose = true
		salt.install_type = "stable"
		salt.masterless = true
    salt.run_highstate = true
  end

end
