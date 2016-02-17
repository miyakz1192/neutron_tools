require 'fog'
require 'pp'
require 'logger'
require 'ostruct'

class AuthInfo < OpenStruct
#this class represents authentication infomation
#has thease attr
# :password,String
# :user_name,String
# :auth_url,String
# :tenant_name,String
end

class OpenStackDriverFactory
  #create OpenStack Driver
  #now version only supports Fog
  #if other driver supports thease must have Fog like interface
  #@param kind [Symbol] :Network, :Identity, :Image, :Compute
  #@param auth_info [AuthInfo] authentication infomation
  def create(kind,auth_info)
    auth = convert_auth_info(auth_info)
    eval("Fog::#{kind}.new(auth)")
  end

protected
  # convert AuthInfo to Fog auth hash
  # @param auth_info [AuthInfo] authentication infomation
  def convert_auth_info(auth_info)
    {
      :provider => 'OpenStack',
      :openstack_api_key => auth_info.password,
      :openstack_username => auth_info.user_name,
      :openstack_auth_url => "#{auth_info.auth_url}/tokens",
      :openstack_tenant => auth_info.tenant_name
    }
  end
end

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

  # input authentication info
  #@param auth_info [AuthInfo] authentication infomation
  def initialize(params = {})
    super
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
end

class IdentityTestEnvironment < IndividualTestEnvironmentBase
  #initialize
  #@param auth_info [AuthInfo] authentication infomation
  def initialize(auth_info)
    super
    @keystone = OpenStackDriverFactory.new.create(:Identity,
                                                  auth_info)
  end

  # ensure given user_name/tenant_name exists
  #@param auth_info [AuthInfo] authentication infomation
  def create_impl(auth_info)
    user_name   = auth_info.user_name
    password    = auth_info.password
    tenant_name = auth_info.tenant_name

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
  #@param auth_info [AuthInfo] authentication infomation
  def delete_impl(auth_info)
    user_name   = auth_info.user_name
    tenant_name = auth_info.tenant_name

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
  #@param auth_info [AuthInfo] authentication infomation
  def initialize(auth_info)
    super
    @glance = OpenStackDriverFactory.new.create(:Image,
                                                 auth_info)
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


module OpenStackObject

  class OpenStackObjectBase < TestEnvironmentBase
    attr_reader :concrete

    @@auth_info = nil
    @@driver_kind = nil
    @@driver = nil

    def self.auth_info=(auth_info)
      @@auth_info = auth_info
    end

    def self.driver
      return @@driver if @@driver
      @@driver = OpenStackDriverFactory.new.create(@@driver_kind,
                                                   @@auth_info)
    end

    def driver
      self.class.driver
    end

    def method_missing(name, *args)
      @concrete.send name, *args
    end
  end

  class NeutronObjectBase < OpenStackObjectBase
    @@driver_kind = :Network
  end

  class Instance < OpenStackObjectBase
    attr_reader :name, :networks

    # @param name [String] instance name
    # @param 0..last [Network]  network object
    def initialize(name, *args)
      raise "not Network object" if args.detect{|a| a.class != Network}
      @name = name
      @networks = args
    end
  end
  
  class Network < NeutronObjectBase
    attr_reader :name, :cidr, :gateway_ip
    def initialize(name, cidr, gateway_ip = nil)
      @name = name
      @cidr = cidr
    end

    def deploy
      @concrete = driver.networks.create(:name => name)

      subnet_param = {:name => "#{name}_subnet",
                      :network_id => @concrete.id,
                      :ip_version => 4,
                      :cidr       => cidr}

      if gateway_ip
        subnet_param.merge!(:gateway_ip => gateway_ip)
      end

      driver.subnets.create(subnet_param)
    end

    def undeploy
      @concrete.destroy if @concrete
    end

    def subnet
      driver.subnets.detect{|s| s.network_id == @concrete.id}
    end

    def self.list
      self.driver.networks
    end
  end
  
  class Router < OpenStackObjectBase
    def initialize(name, *args)
    end

    def add_interface(net)
      raise "not implement error"
    end

    def delete_interface(net)
      raise "not implement error"
    end
  end

  class Routers
    def self.delete_all
      raise "not implement error"
    end
  end
end



class TestEnvironment < TestEnvironmentBase
  attr_accessor :admin_auth_info, :test_auth_info, :objects
  include OpenStackObject

  def initialize(params = {})
    super
    @admin_auth_info = AuthInfo.new(params[:admin_auth_info])
    @test_auth_info = AuthInfo.new(params[:test_auth_info])
    @test_image = params[:test_image]
    @objects = []
  end

  def objects(&block)
    block.call(self)
    self
  end

#  def method_missing(meth_name, *args)
#    logger.info("METHOD MISSING #{meth_name.inspect},#{args.inspect}")
#    obj_name = meth_name
#    obj << obj_name
#    cmd = "@#{obj_name} = \"a\""
#    logger.info("CMD = #{cmd.inspect}")
#    eval(cmd)
#  end

  def configure(&block)
    @id_env = IdentityTestEnvironment.new(@admin_auth_info)
    @id_env.create(@test_auth_info)
    @image_env = ImageTestEnvironment.new(@test_auth_info)
    @image_env.create({:image_name => @test_image})
    logger.info("BUILD OBJECTS")
    self.instance_eval(&block)
  end

  def deploy
    @objects.each do |o|
      o.deploy
    end
  end

  def undeploy
    @objects.reverse.each do |o|
      o.undeploy
    end
    @image_env.delete({:image_name => @test_image})
    @id_env.delete(@test_auth_info)
  end

  def connections(&block)
    logger.info("DEFINE CONNECTIONS")
  end

protected
  def network(name, cidr)
    puts "creating network #{name},#{cidr}"
    Network.auth_info = @test_auth_info
    net = Network.new(name, cidr)
    @objects << net
    return net
  end

  def router(name, *args)
    puts "creating router #{name},#{args.inspect}"
    return name
  end

  def instance(name, *args)
    puts "creating instance #{name},#{args.inspect}"
    return name
  end
end
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
