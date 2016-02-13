require 'fog'
require 'pp'
require 'logger'

class TestEnvironmentBase
  def initialize(params = {})
    @logger = Logger.new(STDOUT)
  end
end

class IdentityTestEnvironment < TestEnvironmentBase
  #initialize
  #params are equals to admin
  def initialize(params)
    super
    @keystone = Fog::Identity.new(params)
  end

  # ensure given user_name/tenant_name exists
  # @param params[:user_name] [String] test user name
  # @param params[:password] [String] test user password
  # @param params[:tenant_name] [String] test tenant_name
  def ensure(params)
    user_name   = params[:user_name]
    password    = params[:password]
    tenant_name = params[:tenant_name]

    @logger.info("check tenant \"#{tenant_name}\" exists")
    unless keystone.tenants.detect{|t| t.name == tenant_name}
      @logger.info("#{tenant_name} does not exist. so make it")
      keystone.tenants.create({:name => tenant_name})
    end

    @logger.info("check user \"#{user_name}\" exists")
    unless keystone.users.detect{|u| u.name == user_name}
      @logger.info("#{user_name} does not exist. so make it")
      tenant_id = keystone.tenants.detect{|t| t.name == tenant_name}.id
      keystone.users.create({:name => user_name,
                             :tenant_id => tenant_id,
                             :password => password})
    end
    @logger.info("show users")
    keystone.users.each do |user|
      @logger.info(user.name)
    end
    @logger.info("show tenants")
    keystone.tenants.each do |t|
      @logger.info(t.name)
    end
  end

protected
  def keystone
    @keystone
  end
end

class ImageTestEnvironment < TestEnvironmentBase
  # test user_name/password/tenant_name
  # @param params[:user_name] [String] test user name
  # @param params[:password] [String] test user password
  # @param params[:tenant_name] [String] test tenant_name
  def initialize(params)
    @glance = Fog::Image.new(params)
  end

protected
  def glance
    @glance
  end
end
##############################################################################
#  config area
##############################################################################
#define OpenStack admin previlege info
admin_previledge_info = {
  :provider => 'OpenStack',
  :openstack_api_key => ENV['OS_PASSWORD'],
  :openstack_username => ENV["OS_USERNAME"],
  :openstack_auth_url => "#{ENV["OS_AUTH_URL"]}/tokens",
  :openstack_tenant => ENV["OS_TENANT_NAME"]
}
#define test previlege info
test_previledge_info = {:user_name => "test_user", 
                        :password => "a", 
                        :tenant_name => "test"}
#instance image
test_image = "cirros-0.3.4-x86_64-disk.img"
##############################################################################
#  code area
##############################################################################
# for OpenStack admin privilege
idenv = IdentityTestEnvironment.new(admin_previledge_info)
idenv.ensure(test_previledge_info)

glance = Fog::Image.new(admin_previledge_info)
puts glance.images.inspect

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
