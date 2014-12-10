#!/usr/bin/env ruby

require 'json'
require 'rest_client'
"sudo gem install rest-client"


module RestAPIBase
  def basic_header
    header = {:content_type => :json, :accept => :json}    
  end
  
  def header_with_token(token)
    header.merge("X-Auth-Token" => token)
  end
end

class String
  def j_to_h
    JSON.parse(self)
  end
end

##########################################################################
# Keystone
##########################################################################
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

##########################################################################
# APIWithIdendity
##########################################################################
class APIWithIdendity
  attr_reader :ip_address, :port
  attr_reader :keystone

  #params[:ip_address] neutron api endpoint
  #params[:port] neutron api endpoint port
  #params[:ketstone] keystone object
  def initialize(params)
    @ip_address = params[:ip_address]
    @port = params[:port]
    @keystone = params[:keystone]
  end
end

##########################################################################
# nova
##########################################################################
class Nova < APIWithIdendity
  attr_reader :ip_address, :port
  
  def uri_base
    "http://#{ip_address}:#{port}/v2"
  end

  def header
    header_with_token(token)
  end

  def id_by_name(name)
    uri = "#{uri_base}#{keystone.tenant_id}/servers/"
    servers = RestClient.get(uri, header).j_to_h
  end
end

##########################################################################
# Neutron
##########################################################################

################
# models
################
class Port
  attr_reader :uuid
end

class SecurityGroupAPI < APIWithIdendity
  def list    
    puts "in SG list"
  end
end

class SecurityGroupRuleAPI < APIWithIdendity  
end

class PortAPI < APIWithIdendity
  def show(uuid)
    return Port.new(uuid)
  end
  
  def ports_by_device_id(device_id)
  end
end


# get port info from neutron-server
class NeutronAPI
  attr_reader :keystone
  attr_reader :security_group, :security_group_rule, :port

  #params[:ip_address] neutron api endpoint
  #params[:port] neutron api endpoint port
  #params[:keystone] keystone
  def initialize(params)
    @security_group = SecurityGroupAPI.new(params)
    @security_group_rule = SecurityGroupRuleAPI.new(params)
    @port = PortAPI.new(params)
  end  

  def sg
    security_group
  end
  
  def sgr
    security_group_rule
  end
end
##########################################################################
# nova
##########################################################################
class NovaAPI < APIWithIdendity
end

##########################################################################
# iptables validator
##########################################################################
class IptablesValidator
  #params[:nova_ip_address] vmhost ip address
  #params[:nova_password] root password
  def validate_iptables(params)
    # sshpass -p miyakz  ssh -o StrictHostKeyChecking=no miyakz@127.0.0.1 sudo iptables-save
  end  
end


##########################################################################
# test code
##########################################################################


# generate chain names
keystone = Keystone.new(:ip_address => "192.168.122.36", :port=>"5000",
                        :user_name => "admin", :tenant_name => "admin", :password => "a")

neutron = NeutronAPI.new(:ip_address => "192.168.122.36", :port => "9696", :keystone => keystone)

nova = Nova.new(:ip_address => "192.168.122.36", :port => "35357", :keystone => keystone)

puts keystone.tenant_id
