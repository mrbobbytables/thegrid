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
    salt.run_highstate = true
    salt.minion_config = "salt/minion"
    salt.grains.config = "salt/minion.d/vagrant.conf"
  end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   sudo apt-get update
  #   sudo apt-get install -y apache2
  # SHELL
end
