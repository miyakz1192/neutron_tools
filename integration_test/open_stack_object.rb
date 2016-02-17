module OpenStackObject

  class OpenStackObjectBase < ObjectBase
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


