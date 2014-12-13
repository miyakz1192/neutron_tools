require 'common/api_with_identity'
require 'common/rest_api_base'
require 'common/errors'
require 'common/neutron_tools_string'

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
  def list    
    puts "in SG list"
  end
end

class SecurityGroupRuleAPI < NeutronAPIBase
end

class PortAPI < NeutronAPIBase
  def list
    uri = "#{uri_base}/ports"
    return RestClient.get(uri, header).j_to_h["ports"]
  end

  def show(uuid)
    raise ShowMustBeSingleUUID.new if uuid.is_a?(Array)
    uri = "#{uri_base}/ports/#{uuid}"
    return RestClient.get(uri, header).j_to_h["port"]
  end

  def list_ids_by_device_id(device_id)
    list.select{|p| p["device_id"] == device_id}.map{|p| p["id"]}
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
