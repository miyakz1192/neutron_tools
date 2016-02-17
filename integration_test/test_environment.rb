
class TestEnvironmentBase < ObjectBase
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
