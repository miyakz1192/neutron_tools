#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) 

require 'json'
require 'rest_client'
require 'openstack/nova'
require 'openstack/neutron'
require 'openstack/keystone'
require 'pp'
#"sudo gem install rest-client"

#porting from neutron's iptables_firewall.py
module IptablesFirewall
protected
  def _ip_prefix_arg(direction, ip_prefix)
    if ip_prefix
      return "-#{direction} #{ip_prefix}"
    else
      ""
    end
  end

  def _convert_sgr_to_iptables_rules(security_group_rules)
    iptables_rules = []
    _drop_invalid_packets(iptables_rules)
    _allow_established(iptables_rules)

    for rule in security_group_rules
      next if rule.ethertype == "IPv6"
      pp rule
      args  = _ip_prefix_arg("s", rule.source_ip_prefix)
      args += _ip_prefix_arg("d", rule.dest_ip_prefix)
      args += _protocol_arg(rule.protocol)
      args += _port_arg('sport',
                        rule.protocol,
                        rule.source_port_range_min,
                        rule.source_port_range_max)
      args += _port_arg('dport',
                        rule.protocol,
                        rule.port_range_min,
                        rule.port_range_max)
      next if args == ""
      args += " -j RETURN"
      pp args
      iptables_rules << args
    end
    iptables_rules << "-j neutron-openvswi-sg-fallback"
  end

  def _drop_invalid_packets(iptables_rules)
    # Always drop invalid packets
    iptables_rules << "-m state --state INVALID -j DROP"
  end

  def _allow_established(iptables_rules)
    iptables_rules << "-m state --state RELATED,ESTABLISHED -j RETURN"
  end

  def _protocol_arg(protocol)
    return "" if protocol == nil

    iptables_rule = "-p #{protocol}"
    # iptables always adds '-m protocol' for udp and tcp
    if ['udp', 'tcp'].include?(protocol)
      iptables_rule += " -m #{protocol}"
    end

    return iptables_rule
  end

  def _port_arg(direction, protocol, 
                port_range_min, port_range_max)
    if ['udp', 'tcp', 'icmp', 'icmpv6'].include?(protocol)==false||
        port_range_min == nil
      return ""
    end

    if ['icmp', 'icmpv6'].include?(protocol)
      if port_range_max != nil
        return "--#{protocol}-type #{port_range_min}/#{port_range_max}"
      else
        return "--#{protocol}-type #{port_range_min}"     
      end
    elsif port_range_min == port_range_max
      return "--#{direction} #{port_range_min}"
    else
      return "-m multiport --#{direction}s #{port_range_min}:#{port_range_max}"
    end
  end

end

class IptablesValidator
  include IptablesFirewall
  attr_reader :nova, :neutron, :instance_name

  #params[:openstack][:nova]
  #params[:openstack][:neutron]
  #params[:instance_name]
  def initialize(params)
    @nova = params[:openstack][:nova]
    @neutron = params[:openstack][:neutron]
    @instance_name = params[:instance_name]
    # sshpass -p miyakz  ssh -o StrictHostKeyChecking=no miyakz@127.0.0.1 sudo iptables-save
  end  

  def check_all_port
    instance = nova.instance_by_name(instance_name)
    ipt_data = iptables_data
    neutron.ports.list_by_device_id(instance.id).each do |port|
      _check_one_port(ipt_data, port)
    end
  end

  def check_one_port(port)
    _check_one_port(iptables_data, port)
  end

protected
  
  def _check_one_port(ipt_data, port)
    puts "=========================================="
    #collect all sgr
    all_sgr = []
    all_ports = neutron.ports.list

    port.sgids.each do |sgid| 
      #ingress context
      all_sgr += implicitly_allowed_ip_own_sg(all_ports, port, sgid)
      all_sgr += allowed_rule(sgid)
      all_sgr += implicitly_allowed_ip_remote_sg(all_ports, port, sgid)
      all_sgr += dhcp_rules(port, all_ports)
      
      #egress context
      #TODO: qqq ...

      pp to_ingress_iptable_rules(port, all_sgr)
    end  

    check_ingress(all_sgr, ipt_data, port)
    check_egress(all_sgr, ipt_data, port)
  end

  def implicitly_allowed_ip_own_sg(all_ports, this_port, own_sgid)
    sgr = []
    #collect ingress ip address from my sg
    all_ports.select{|p| p.sgids.include?(own_sgid)}.each do |_port|
      #skip myself
      next if _port.mac_address == this_port.mac_address
      
      _port.fixed_ips.each do |ip|
        params = {"direction" => "ingress",
          "source_ip_prefix" => "#{ip["ip_address"]}/32"}
        
        puts "item found #{_port.mac_address}, #{ip["ip_address"]}"
        sgr << SecurityGroupRule.new(params)
      end
    end
    return sgr
  end

  def allowed_rule(own_sgid)
    neutron.sgrs.list_by_sgid(own_sgid).select{|s| 
      s.direction == "ingress"}
  end

  def implicitly_allowed_ip_remote_sg(all_ports, this_port, own_sgid)
    res_sgr = []
    neutron.sgrs.list_by_sgid(own_sgid).each do |sgr|
      next unless sgr.remote_group_id 
      next if sgr.remote_group_id == sgr.security_group_id
      
      ports = all_ports.select do |_port|
          this_port.sgids.include?(sgr.remote_group_id)
      end
      
      this_ports.map do |_port|
        if sgr.direction == "ingress"
          _port.fixed_ips.each do |ip|
            params = {"direction" => sgr.direction,
              "source_ip_prefix" => "#{ip["ip_address"]}/32"}
            
            res_sgr << SecurityGroupRule.new(params)
          end
        elsif sgr.direction == "egress"
          _port.fixed_ips.each do |ip|
            params = {"direction" => sgr.direction,
              "dest_ip_prefix" => "#{ip["ip_address"]}/32"}
            
            res_sgr << SecurityGroupRule.new(params)
          end
        else
          puts "WARNING: invalid direction #{sgr.direction}"
        end
      end
    end
    return res_sgr
  end

  def dhcp_rules(port, all_ports)
    
    sgr = []

    dhcp_ports = all_ports.select{ |p| 
      port.network_id == p.network_id && 
      p.device_owner =~ /dhcp/ &&
      port.id != p.id
    }

    puts "dhcp_ports = #{dhcp_ports.inspect}"

    dhcp_ports.each do |dhcp_port|
      
      dhcp_port.fixed_ips.each do |ip|
        params = {"direction" => "ingress",
          "source_ip_prefix" => "#{ip["ip_address"]}/32",
          "protocol" => "udp",
          "source_port_range_min" => 67,
          "source_port_range_max" => 67,
          "port_range_min" => 68,
          "port_range_max" => 68}
        
        puts "item found dhcp #{ip["ip_address"]}"
        sgr << SecurityGroupRule.new(params)
      end
    end
    return sgr
  end

  def to_ingress_iptable_rules(port, sgrs)
    chain_name = port_to_ingress_chain_name(port)
    
    _convert_sgr_to_iptables_rules(sgrs).map do |r|
      "-A #{chain_name} #{r}"
    end
  end

  def check_ingress(all_sgr, ipt_data, port)
    chain_name = port_to_ingress_chain_name(port)
    ipt = ipt_data.grep(/#{chain_name}/)
  end


  def check_egress(all_sgr, ipt_data, port)
    
  end

  def port_to_ingress_chain_name(port)
    "neutron-openvswi-i#{port.id[0..9]}"
  end

  def port_to_egress_chain_name(port)
    "neutron-openvswi-o#{port.id[0..9]}"
  end

  def iptables_data
    `sudo iptables-save`.split("\n")
  end
end


keystone = Keystone.new(:ip_address => "192.168.122.36", 
                        :port=>"5000",
                        :user_name => "admin", 
                        :tenant_name => "admin", :password => "a")

neutron = NeutronAPI.new(:ip_address => "192.168.122.36", 
                         :port => "9696", :keystone => keystone)

nova = NovaAPI.new(:ip_address => "192.168.122.36",
                   :port => "8774", :keystone => keystone)

openstack = {:nova => nova, :neutron => neutron}
ipv = IptablesValidator.new(:openstack => openstack,
                            :instance_name => "test1")

ipv.check_all_port
