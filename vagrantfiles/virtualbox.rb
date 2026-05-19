ENV["VBOX_RELEASE_LOG_DEST"] ||= "nofile"
ENV["VBOX_LOG_DEST"] ||= "nofile"

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
    vb.memory = 2048
  end
end
