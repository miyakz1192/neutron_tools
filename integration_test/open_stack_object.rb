module OpenStackObject

  class OpenStackObjectBase < ObjectBase
    attr_reader :concrete
    @@auth_info = nil

    def self.auth_info=(ai)
      @@auth_info = ai
    end

    def driver
      self.class.driver
    end

    def method_missing(name, *args)
      @concrete.send name, *args
    end

    def deploy
      raise "not implement error(deploy)"
    end
    
    def undeploy
      if @concrete
        puts "++UNDEPLOY #{@concrete.class.name},#{@concrete.name},#{@concrete.id}"
        puts @concrete.destroy
      end
      self
    end
  end

  class NeutronObjectBase < OpenStackObjectBase
    def self.driver
      OpenStackDriverFactory.new.create(:Network,
                                        @@auth_info)
    end
  end

  class NovaObjectBase < OpenStackObjectBase
    def self.driver
      OpenStackDriverFactory.new.create(:Network,
                                        @@auth_info)
    end
  end

  class Port < NeutronObjectBase
    def self.list
      self.driver.ports
    end
  end
  
  class Network < NeutronObjectBase
    attr_reader :name, :cidr, :gateway_ip
    def initialize(name, cidr, gateway_ip = nil)
      @name = name
      @cidr = cidr
      @subnet = nil
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
      self
    end

    def subnet
      @subnet if @subnet
      @subnet = driver.subnets.detect{|s| s.network_id==@concrete.id}
    end

    def self.list
      self.driver.networks
    end

    def self.delete_all
      list.each do |net|
        puts "DELETE #{net.name},#{net.id},#{net.tenant_id}"
        net.destroy rescue puts "ERROR: net delete"
      end
    end
  end
  
  class Router < NeutronObjectBase
    attr_reader :name, :args, :networks

    def initialize(name, *args)
      @name = name
      @args = args
      @networks = @args.select{|a| a.class == Network}
    end

    def deploy
      @concrete = driver.routers.create(:name => name)
      puts "NETWORKS #{networks.count}" rescue puts "ERROR"
      networks.each do |net|
        add_interface(net)
      end
    end

    def undeploy
      return unless @concrete
      networks.each do |net|
        delete_interface(net)
      end
      super
    end

    def add_interface(net)
      return unless @concrete
      driver.add_router_interface(@concrete.id,
                                  net.subnet.id)
    end

    def delete_interface(net)
      return unless @concrete
      driver.remove_router_interface(@concrete.id,
                                     net.subnet.id)
    end

    def ports
      return unless @concrete
      Port.list.select{|port| port.device_id == @concrete.id}
    end

    def self.list
      self.driver.routers 
    end
  end

  class Routers < NeutronObjectBase
    def self.delete_all
      raise "not implement error"
    end
  end

  class Instance < NovaObjectBase
    attr_reader :name, :networks, :image, :flavor, :exparams
    #default value(image, flavor)
    @@default

    #instance object initializer
    # @param name [String] instance name
    # @param arg(Network) [Network] Network object reference(*N)
    # @param arg(Hash) [Hash] other option
    def initialize(name, *args)
      @name = name
      @networks = self.class.find_network_from(args)
      @exparams  = self.class.find_exparams_from(args)
      if @exparams
        @image = @exparams[:image] || @@default[:image]
        @flavor = @exparams[:flavor] || @@default[:flavor]
      end
    end

    def self.default=(default_value)
      @@default = default_value
    end


    def self.find_network_from(args)
      networks = args.select{|a| a.is_a?(Network)}
      if networks.empty?
        raise "Network object not found" 
      end
      networks
    end

    def self.find_exparams_from(args)
      args.detect{|a| a.is_a?(Hash)}
    end

  end

end


