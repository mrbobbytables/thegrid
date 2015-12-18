Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "mesos"
  config.vm.network "private_network", ip: "192.168.99.10"
  config.vm.synced_folder "salt/roots", "/srv/salt/"
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
		# see here for the bootstrap reasoning:
		# https://github.com/mitchellh/vagrant/issues/5973#issuecomment-137276605
		salt.bootstrap_options = '-F -c /tmp/ -P'
    salt.grains_config = "salt/minion.d/vagrant.conf"
  end

end
