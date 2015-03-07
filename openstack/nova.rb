$:.unshift File.dirname(__FILE__) 

require './common/api_with_identity'
require './common/rest_api_base'
require './common/errors'
require './common/neutron_tools_string'
require './openstack/models'

class Instance < OpenStackObjectModel
  def host
    @myself["OS-EXT-SRV-ATTR:hypervisor_hostname"]
  end
end

class NovaAPI < APIWithIdendity
  include RestAPIBase
  
  def uri_base
    "http://#{ip_address}:#{port}/v2"
  end

  def header
    header_with_token(keystone.token)
  end

  def servers
    puts "servers"
    uri = "#{uri_base}/#{keystone.tenant_id}/servers/detail"
    puts RestClient.get(uri, header)
    RestClient.get(uri, header).j_to_h["servers"].map do |o|
#      puts("instance=#{o.name}")
      Instance.new(o)
    end
  end

  def instance_id_by_name(name)
    instance_by_name(name).id
  end

  def instance_by_name(name)
    s = servers.select{|s| s.name == name}
    if s.count > 1
      raise MultipleInstanceNameFound.new, "instance name=#{name}"
    end
    return s.first
  end
end

