
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
      u = keystone.users.create({:name => user_name,
                                 :tenant_id => tenant_id,
                                 :password => password})
      logger.info "user = #{u.inspect}"
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
  attr_reader :image
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
    logger.info("image_location = #{image_location}")
    unless glance.images.detect{|i| i.name == image_name}
      logger.info("crate image \"#{image_name}\"")
      @image = glance.images.create({:name => image_name,
                                     :size => image_size,
                                     :disk_format => "qcow2",
                                     :container_format => "bare",
                                     :location => image_location})
      logger.info("crate image \"#{image_name}\",#{image.id} done. check exists")
    end

    logging_res(image_name)
  end

  def delete_impl(params = {})
    puts `glance image-list`

    if image
      image.destroy
      logging_res(image.name)
    end
  end

protected
  def glance
    @glance
  end

  def logging_res(image_name)
    logger.info("===show images===")
    img = glance.images.detect{|i| i.name == image_name}
    if img
      logger.info("check res == #{img.name}")
    else
      logger.info("no such as image #{image_name}")
    end
    puts `glance image-list`
  end
end


class TestEnvironment < TestEnvironmentBase
  attr_accessor :admin_auth_info, :test_auth_info, :default, :objects
  include OpenStackObject

  #TODO: argument validatoin
  def initialize(params = {})
    super
    @admin_auth_info = params[:admin_auth_info]
    @test_auth_info  = params[:test_auth_info]
    @default = params[:default]
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

  def deploy(&block)
    begin
      @id_env = IdentityTestEnvironment.new(@admin_auth_info)
      @id_env.create(@test_auth_info)
      @image_env = ImageTestEnvironment.new(@test_auth_info)
      @image_env.create({:image_name => @default[:image]})
      logger.info("BUILD OBJECTS")
      self.instance_eval(&block)
    rescue => e
      logger.error("error occured #{e.message} ROLLBACK START")
      logger.error("TRACE:")
      logger.error(e.backtrace.join('\n').inspect)
      logger.error(e.backtrace.inspect)
      undeploy 
      logger.error("ROLLBACK END")
      raise e
    end
    puts `glance image-list`
  end

  def exec(&block)
    self.instance_eval(&block)
  end

  def undeploy(&block)
    @objects.reverse.each do |o|
      o.undeploy
    end
    self.instance_eval(&block) if block
    @image_env.delete
    @id_env.delete(@test_auth_info)
  end

  def with(auth_info, &block)
    #switch auth_info
    OpenStackObjectBase.auth_info = auth_info
    self.instance_eval(&block)
  end

  def before_undeploy_finish(&block)
    block.call
  end

  def connections(&block)
    logger.info("DEFINE CONNECTIONS")
  end

  def delete_all_network_resources
    with(@test_auth_info) do
      Router.delete_all
      Port.delete_all
      Network.delete_all
    end
  end

protected
  def network(name, cidr)
    logger.info "creating network #{name},#{cidr}"
    net = Network.new(name, cidr)
    net.deploy
    @objects << net
    net
  end

  def router(name, *args)
    logger.info "creating router #{name}"
    router = Router.new(name, *args)
    router.deploy
    @objects << router
    router
  end

  # create instance
  # caller can specify Network option simpley like as
  #   instance "instance2", net1, net2
  # additional option can also specified as Hash object
  #   instance "instance2", net1, net2, {:flavor => "m1.tiny", :image => "imagename"}
  # @param name [String] instance name
  # @param arg(Network) [Network] Network object reference(*N)
  # @param arg(Hash) [Hash] other option
  # @param [:flavor] [String] flavor name(default is "default_flavor")
  # @param [:image] [String] image name(default is "default_image")
  def instance(name, *args)
    logger.info "creating instance #{name}"
    Instance.default = @default
    instance = Instance.new(name, *args)
    instance.deploy
    @objects << instance
    logger.info instance.inspect
    instance
  end
end
