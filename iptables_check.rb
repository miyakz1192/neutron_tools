#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) 

require 'json'
require 'rest_client'
require 'openstack/nova'
require 'openstack/neutron'
require 'openstack/keystone'
#"sudo gem install rest-client"

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
=begin
keystone = Keystone.new(:ip_address => "192.168.122.36", :port=>"5000",
                        :user_name => "admin", :tenant_name => "admin", :password => "a")

neutron = NeutronAPI.new(:ip_address => "192.168.122.36", :port => "9696", :keystone => keystone)

nova = NovaAPI.new(:ip_address => "192.168.122.36", :port => "8774", :keystone => keystone)

puts keystone.tenant_id
instance_id = nova.id_by_name("test1")
puts p = neutron.ports.list_ids_by_device_id(instance_id)
puts neutron.ports.show(p.first)
=end
