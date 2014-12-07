#!/usr/bin/env ruby

require 'json'


##########################################################################
# Keystone
##########################################################################
class Keystone
  attr_reader :ip_address, :port, :user_name, :password, :tenant_name
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
  end

  def token
    `curl -s -X POST http://#{ip_address}:#{port}/v2.0//tokens -H "Content-Type: application/json" -H "Accept: application/json" -H "User-Agent: python-keystoneclient" -d '{"auth": {"tenantName": "#{tenant_name}", "passwordCredentials": {"username": "#{user_name}", "password": "#{password}"}}}'| jq .access.token.id | sed -e 's/\"//g'`
  end
  
end

##########################################################################
# APIWithIdendity
##########################################################################
class APIWithIdendity
  attr_reader :keystone

  def initialize(keystone)
    @keystone = keystone
  end  
end

##########################################################################
# Neutron
##########################################################################
class Port
  attr_reader :uuid
end

class NeutronAPIBase < APIWithIdendity
  attr_reader :ip_address, :port
  
  #params[:ip_address] neutron api endpoint
  #params[:port] neutron api endpoint port
  #params[:keystone] keystone
  def initialize(params)
    super(params[:keystone])
    @ip_address = params[:ip_address]
    @port = params[:port]
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
  def show(uuid)
    return Port.new(uuid)
  end
  
  def ports_by_device_id(device_id)
    `curl -s -X GET http://#{ip_address}:#{port}/v2.0//tokens -H "Content-Type: application/json" -H "Accept: application/json" -H "User-Agent: python-keystoneclient" -d '{"auth": {"tenantName": "#{tenant_name}", "passwordCredentials": {"username": "#{user_name}", "password": "#{password}"}}}'| jq .access.token.id | sed -e 's/\"//g'`
    # -H "Accept: application/json" -H "X-Auth-Token: $TOKEN"
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

