require 'pp'
require 'logger'
require './object_base'
require './open_stack_object'
require './test_environment'
require './open_stack_driver'
require './auth_info'

############################################################################
#  config area
############################################################################

auth_url = "http://192.168.122.84:5000/v2.0"

#define OpenStack admin authentication info
admin_auth = {:user_name => "admin",
              :password => "a", 
              :tenant_name => "admin",
              :auth_url => auth_url}
#define test authentication info
test_auth  = {:user_name => "test_user", 
              :password => "a", 
              :tenant_name => "test",
              :auth_url => auth_url}

#instance image
default_image = "cirros-0.3.4-x86_64-disk.img"
# cirros-0.3.4-x86_64-disk.img is available following url
# wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
default_flavor = "m1.tiny"
############################################################################

admin_auth = AuthInfo.new(admin_auth)
test_auth  = AuthInfo.new(test_auth)

env = TestEnvironment.new(:admin_auth_info => admin_auth, 
                          :test_auth_info => test_auth,
                          :default => {:image => default_image,
                                       :flavor => default_flavor})
include OpenStackObject
############################################################################
#  DSL area 
############################################################################
#
#

#env.delete_all_network_resources
#exit 0

net1 = nil
router1 = nil
env.deploy do
  with(test_auth) do
    net1 = network "net1", "192.168.1.0/24"
    net2 = network "net2", "192.168.2.0/24"
    network "net3", "192.168.3.0/24"
    router1 = router "router1", net1, net2, {:routes => ""}
    instance "instance1", net1, net2
  end
end

env.exec do
  with(test_auth) do
    puts "##############"
    puts net1.name
    puts net1.subnet.name
    puts "##############"
    puts "EXEC &&&&&&&&&&&&&&&&&"
    puts Network.list.map{|o| "#{o.name},#{o.id}"}
    puts Router.list.map{|o| "#{o.name},#{o.id}"}
  end
end

env.undeploy do
  before_undeploy_finish do
    with(test_auth) do
      puts "BEFORE UNDEPLOY FINISH &&&&&&&&&&&&&&&&&"
      puts Network.list.map{|o| "#{o.name},#{o.id}"}
      puts Router.list.map{|o| "#{o.name},#{o.id}"}
    end
  end
end



puts "================END==================="
