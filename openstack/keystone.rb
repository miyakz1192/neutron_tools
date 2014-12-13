require 'common/neutron_tools_string'

class Keystone
  include RestAPIBase
  attr_reader :ip_address, :port, :user_name, :password, :tenant_name
  attr_reader :tenant_id
  #params[:ip_address]
  #params[:port]
  #params[:user_name]
  #params[:pass]
  #params[:tenant_name]
  #params[:account_file]
  def initialize(params)
    @ip_address = params[:ip_address]
    @port = params[:port]
    @user_name = params[:user_name]
    @password = params[:password]
    @tenant_name = params[:tenant_name]
    @tenant_id = get_tenant_id(tenant_name)
  end

  def uri_base
    "http://#{ip_address}:#{port}/v2.0"
  end

  def token
    uri = "#{uri_base}/tokens"
    data = {"auth" =>{"tenantName" => "#{tenant_name}", 
                      "passwordCredentials" => 
                               {"username" => "#{user_name}", 
                                "password"=> "#{password}"}}}
    res = RestClient.post(uri, data.to_json, basic_header).j_to_h
    return res["access"]["token"]["id"]
  end

  def get_tenant_id(name)
    uri = "#{uri_base}/tenants"
    tenants = RestClient.get(uri, header_with_token(token)).j_to_h
    return tenants["tenants"].detect{|t| t["name"] == name}["id"]
  end
end

