require 'fog'
require 'pp'
require 'logger'

class TestEnvironmentBase
  def initialize(params = {})
    @logger = Logger.new(STDOUT)
  end
protected
  def logger
    @logger
  end
end

class IndividualTestEnvironmentBase < TestEnvironmentBase
  @@auth_url = ""

  # input authentication info
  # @param params[:user_name] [String] test user name
  # @param params[:password] [String] test user password
  # @param params[:tenant_name] [String] test tenant_name
  def initialize(params = {})
    super
    @auth_info = {
      :provider => 'OpenStack',
      :openstack_api_key => params[:password],
      :openstack_username => params[:user_name],
      :openstack_auth_url => "#{@@auth_url}/tokens",
      :openstack_tenant => params[:tenant_name]
    }
  end

  def create(params = {})
    logger.info("*** [START] create@#{self.class.name} ***")
    create_impl(params)
    logger.info("*** [END] create@#{self.class.name} ***")
  end
  
  def delete(params = {})
    logger.info("*** [START] delete@#{self.class.name} ***")
    delete_impl(params)
    logger.info("*** [END] delete@#{self.class.name} ***")
  end

  def self.auth_url=(url)
    @@auth_url = url
  end

protected
  def auth_info
    @auth_info
  end
end

class IdentityTestEnvironment < IndividualTestEnvironmentBase
  #initialize
  #params must be admin_auth_info
  def initialize(params)
    super(params)
    #params set to auth_info
    @keystone = Fog::Identity.new(auth_info) 
  end

  # ensure given user_name/tenant_name exists
  # @param params[:user_name] [String] test user name
  # @param params[:password] [String] test user password
  # @param params[:tenant_name] [String] test tenant_name
  def create_impl(params)
    user_name   = params[:user_name]
    password    = params[:password]
    tenant_name = params[:tenant_name]

    logger.info("check tenant \"#{tenant_name}\" exists")
    unless keystone.tenants.detect{|t| t.name == tenant_name}
      logger.info("#{tenant_name} does not exist. so make it")
      keystone.tenants.create({:name => tenant_name})
    end

    logger.info("check user \"#{user_name}\" exists")
    unless keystone.users.detect{|u| u.name == user_name}
      logger.info("#{user_name} does not exist. so make it")
      tenant_id = keystone.tenants.detect{|t| t.name == tenant_name}.id
      keystone.users.create({:name => user_name,
                             :tenant_id => tenant_id,
                             :password => password})
    end
    logging_res
  end

  # delete given user_name/tenant_name
  # @param params[:user_name] [String] test user name
  # @param params[:password] [String] test user password
  # @param params[:tenant_name] [String] test tenant_name
  def delete_impl(params)
    user_name   = params[:user_name]
    tenant_name = params[:tenant_name]

    user   = keystone.users.detect{|u| u.name == user_name}
    tenant = keystone.tenants.detect{|t| t.name == tenant_name}

    user.destroy if user
    tenant.destroy if tenant

    logging_res
  end

protected
  def keystone
    @keystone
  end

  def logging_res
    logger.info("===show users===")
    keystone.users.each do |user|
      logger.info(user.name)
    end
    logger.info("===show tenants===")
    keystone.tenants.each do |t|
      logger.info(t.name)
    end
  end
end

class ImageTestEnvironment < IndividualTestEnvironmentBase
  IMAGE_FILE_DIR = "#{File.expand_path(File.dirname(__FILE__))}/materials/images"

  # params is test_auth_info
  # @param params[:user_name] [String] test user name
  # @param params[:password] [String] test user password
  # @param params[:tenant_name] [String] test tenant_name
  def initialize(params)
    super(params)
    @glance = Fog::Image.new(auth_info)
  end

  # ensure specified image exists. 
  # user ensure image exists in matarials/images
  # @param params[:image_name] [String] image_name
  def create_impl(params = {})
    image_name = params[:image_name]
    image_location = "#{IMAGE_FILE_DIR}/#{image_name}"
    image_size = File.size(image_location)

    logger.info("check image \"#{image_name}\" exists")
    unless glance.images.detect{|i| i.name == image_name}
      logger.info("crate image \"#{image_name}\"")
      glance.images.create({:name => image_name,
                            #:size => image_size,
                            :disk_format => "qcow2",
                            :container_format => "bare",
                            :location => image_location})
      logger.info("crate image \"#{image_name}\" done. check exists")
    end

    logging_res(image_name)
  end

  def delete_impl(params = {})
    image_name = params[:image_name]

    image = glance.images.detect{|i| i.name == image_name}
    image.destroy if image
    logging_res(image_name)
  end

protected
  def glance
    @glance
  end

  def logging_res(image_name)
    logger.info("===show images===")
    image = glance.images.detect{|i| i.name == image_name}
    if image
      logger.info("check res == #{image.name}")
    else
      logger.info("no such as image #{image_name}")
    end
  end
end

class InstanceOpenStackObject
  def self.can_initialize?(object_name)
    /^instance/ =~ object_name
  end
end

class NetworkOpenStackObject
  def self.can_initialize?(object_name)
    /^net/ =~ object_name
  end
end

class RouterOpenStackObject
  def self.can_initialize?(object_name)
    /^router/ =~ object_name
  end
end

class OpenStackObject
  def self.instanciate
    puts self.class.name
    puts self.class.constants.grep(/OpenStackObject/).delete_if{|i| i == self.class.name}
  end
end



class TestEnvironment < TestEnvironmentBase
  def initialize(params = {})
    super
    @obj = []
  end

  def objects(&block)
    block.call(self)
    self
  end

  def method_missing(meth_name, *args)
    logger.info("METHOD MISSING #{meth_name.inspect},#{args.inspect}")
    obj_name = meth_name
    obj << obj_name
    cmd = "@#{obj_name} = \"a\""
    logger.info("CMD = #{cmd.inspect}")
    eval(cmd)
  end

  def build
    logger.info("BUILD OBJECTS")
    logger.info(obj.inspect)
  end

  def connections(&block)
    logger.info("DEFINE CONNECTIONS")
    block.call(self)
  end

  def obj
    @obj
  end
end
############################################################################
#  config area
############################################################################
#define OpenStack admin authentication info
admin_auth_info = {:user_name => "admin",
                   :password => "a", 
                   :tenant_name => "admin"}
#define test authentication info
test_auth_info  = {:user_name => "test_user", 
                   :password => "a", 
                   :tenant_name => "test"}
#auth url
IndividualTestEnvironmentBase.auth_url = "http://192.168.122.84:5000/v2.0"
#instance image
test_image = "cirros-0.3.4-x86_64-disk.img"
# cirros-0.3.4-x86_64-disk.img is available following url
# wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
############################################################################
#  code area
############################################################################
## for OpenStack admin privilege
#id_env = IdentityTestEnvironment.new(admin_auth_info)
#id_env.create(test_auth_info)
#
#image_env = ImageTestEnvironment.new(test_auth_info)
#image_env.create({:image_name => test_image})
#
#image_env.delete({:image_name => test_image})
#id_env.delete(test_auth_info)

env = TestEnvironment.new
############################################################################
#  DSL area 
############################################################################

env.objects do |e|
  e.net1 "192.168.1.0/24"
  e.net2 "192.168.2.0/24"
  e.router1
  e.instance1
  e.instance2
end

puts "=================================="
puts env.obj.inspect
puts "=================================="

env.connections do |e|
#  e.router1 e.net1
#  e.instance1 e.net1 e.net2
end

OpenStackObject.instanciate


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
