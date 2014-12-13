$:.unshift File.dirname(__FILE__) 

require './common/api_with_identity'
require './common/rest_api_base'
require './common/errors'
require './common/neutron_tools_string'

class NovaAPI < APIWithIdendity
  include RestAPIBase
  
  def uri_base
    "http://#{ip_address}:#{port}/v2"
  end

  def header
    header_with_token(keystone.token)
  end

  def servers
    uri = "#{uri_base}/#{keystone.tenant_id}/servers/detail"
    return RestClient.get(uri, header).j_to_h["servers"]
  end

  def id_by_name(name)
    s = servers.select{|s| s["name"] == name}
    if s.count > 1
      raise MultipleInstanceNameFound.new, "instance name=#{name}"
    end
    return s.first["id"]
  end
end
