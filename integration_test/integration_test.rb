env.configure do
  net1 = network "net1", "192.168.1.0/24"
  net2 = network "net2", "192.168.2.0/24"
  network "net3", "192.168.3.0/24"
  router "router1", "net1", "net2", {:routes => ""}
  instance "instance2", net1, net2

  puts "&&&&&&&&&&&&&&&&&"
  puts Network.list.inspect

#TODO:
#  router1.add_interface net1
#  router1.add_interface net2

#  OpenStackObject.instanciate
  #

# TODO:
#  instance("instance1") do
#    network net1,net2
#    image "cirros.img"
#  end

#TODO:
#  application("app1") do 
#    copy "src_file", "dst_file"
#    shell "sudo chkconfig add /etc/init.d/S99z_udp"
#    method "default" do #default is network_namespace_injection
#      instance_user_name "aaa"
#      instance_password "bbb"
#      network_node_user_name "zzz"
#      network_node_password "qqq"
#    end
#  end
#
#  app1.apply(instance1)
end

env.deploy

