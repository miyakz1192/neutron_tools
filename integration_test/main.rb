require 'pp'
require 'logger'
require 'open_stack_object'
require 'open_stack_driver'
require 'auth_info'
require 'test_environment'

############################################################################
#  config area
############################################################################

auth_url = "http://192.168.122.84:5000/v2.0"

#define OpenStack admin authentication info
admin_auth_info = {:user_name => "admin",
                   :password => "a", 
                   :tenant_name => "admin",
                   :auth_url => auth_url}
#define test authentication info
test_auth_info  = {:user_name => "test_user", 
                   :password => "a", 
                   :tenant_name => "test",
                   :auth_url => auth_url}

#instance image
test_image = "cirros-0.3.4-x86_64-disk.img"
# cirros-0.3.4-x86_64-disk.img is available following url
# wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
############################################################################
#  code area
############################################################################

env = TestEnvironment.new(:admin_auth_info => admin_auth_info, 
                          :test_auth_info => test_auth_info,
                          :test_image => test_image)
include OpenStackObject
############################################################################
#  DSL area 
############################################################################
#

net1 = nil
env.configure do
  net1 = network "net1", "192.168.1.0/24"
  net2 = network "net2", "192.168.2.0/24"
  network "net3", "192.168.3.0/24"
  router "router1", "net1", "net2", {:routes => ""}
  instance "instance2", net1, net2

  puts "&&&&&&&&&&&&&&&&&"
  puts Network.list.inspect
end

env.deploy
puts "&&&&&&&&&&&&&&&&&"
puts Network.list.inspect

puts "##############"
puts net1.name
puts net1.subnet.name
puts "##############"


#eval(File.new("./integration_test.rb").read)
env.undeploy
puts "&&&&&&&&&&&&&&&&&"
puts Network.list.inspect

puts "================END==================="

##for test privilege
#nova = Fog::Compute.new({
#  :provider => 'OpenStack',
#  :openstack_api_key => ENV['OS_PASSWORD'],
#  :openstack_username => ENV["OS_USERNAME"],
#  :openstack_auth_url => "#{ENV["OS_AUTH_URL"]}/tokens",
#  :openstack_tenant => ENV["OS_TENANT_NAME"]
#})
#
##for test privilege
#neutron = Fog::Network.new({
#  :provider => 'OpenStack',
#  :openstack_api_key => ENV['OS_PASSWORD'],
#  :openstack_username => ENV["OS_USERNAME"],
#  :openstack_auth_url => "#{ENV["OS_AUTH_URL"]}/tokens",
#  :openstack_tenant => ENV["OS_TENANT_NAME"]
#})
#
#neutron.networks.each do |net|
#  puts "#{net.id},#{net.name}"
#end

#flavor = conn.flavors.find { |f| f.name == 'm1.tiny' }
#puts flavor.inspect

#image_name = 'Cirros 0.3.0 x86_64'
#image = conn.images.find { |i| i.name == image_name }
#
#puts "#{'Creating server'} from image #{image.name}..."
#server = conn.servers.create :name => "fogvm-#{Time.now.strftime '%Y%m%d-%H%M%S'}",
#                             :image_ref => image.id,
#                             :flavor_ref => flavor.id,
#                             :key_name => 'testkey01'
#server.wait_for { ready? }
