require 'common/api_with_identity'
require 'common/rest_api_base'
require 'common/errors'
require 'common/neutron_tools_string'
require 'openstack/models'

class Port < OpenStackObjectModel
  def host
    @myself["binding:host_id"]
  end

  #security_groups just returns sgids
  #NOTICE not security group model objects...
  def sgids
    self.security_groups
  end
end

class SecurityGroup < OpenStackObjectModel
end

class SecurityGroupRule < OpenStackObjectModel
end

class NeutronAPIBase < APIWithIdendity
  include RestAPIBase

  def uri_base
    "http://#{ip_address}:#{port}/v2.0"
  end

  def header
    header_with_token(keystone.token)
  end  
end

class SecurityGroupAPI < NeutronAPIBase
  def show(uuid)
    uri = "#{uri_base}/security-groups/#{uuid}"
    data = RestClient.get(uri, header).j_to_h["security_group"]
    SecurityGroup.new(data)
  end
end

class SecurityGroupRuleAPI < NeutronAPIBase
  
  def list
    uri = "#{uri_base}/security-group-rules"
    r = RestClient.get(uri, header).j_to_h["security_group_rules"]
    r.map do |sgr|
      SecurityGroupRule.new(sgr)
    end
  end
  
  def list_by_security_group_id(sgid)
    list.select{|sgr| sgr.security_group_id == sgid}
  end

  #syntax sugar
  def list_by_sgid(sgid)
    list_by_security_group_id(sgid)
  end

end

class PortAPI < NeutronAPIBase
  def list
    uri = "#{uri_base}/ports"
    RestClient.get(uri, header).j_to_h["ports"].map do |port|
      Port.new(port)
    end
  end

  def show(uuid)
    raise ShowMustBeSingleUUID.new if uuid.is_a?(Array)
    uri = "#{uri_base}/ports/#{uuid}"
    return Port.new(RestClient.get(uri, header).j_to_h["port"])
  end

  def list_ids_by_device_id(device_id)
    list_by_device_id(device_id).map{|p| p.id}
  end

  def list_by_device_id(device_id)
    list.select{|p| p.device_id == device_id}
  end
end

# get port info from neutron-server
class NeutronAPI
  attr_reader :keystone
  attr_reader :security_groups, :security_group_rules, :ports

  #params[:ip_address] neutron api endpoint
  #params[:port] neutron api endpoint port
  #params[:keystone] keystone
  def initialize(params)
    @security_groups = SecurityGroupAPI.new(params)
    @security_group_rules = SecurityGroupRuleAPI.new(params)
    @ports = PortAPI.new(params)
  end  

  #syntax sugar
  def sgs
    security_groups
  end
  
  #syntax sugar
  def sgrs
    security_group_rules
  end
end
