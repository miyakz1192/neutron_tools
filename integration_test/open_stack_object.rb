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

    def deploy
      raise "not implement error(deploy)"
    end
    
    def undeploy
      raise "not implement error(undeploy)"
    end

    def undeploy
      @concrete.destroy if @concrete
      self
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
  end
  
  class Router < OpenStackObjectBase
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
      networks.each do |net|
        delete_interface(net)
      end
      super
    end

    def add_interface(net)
      driver.add_router_interface(@concrete.id,
                                  net.subnet.id)
    end

    def delete_interface(net)
      driver.remove_router_interface(@concrete.id,
                                     net.subnet.id)
    end

    def ports
      Port.list.select{|port| port.device_id == @concrete.id}
    end

    def self.list
      self.driver.routers 
    end
  end

  class Routers
    def self.delete_all
      raise "not implement error"
    end
  end
end


