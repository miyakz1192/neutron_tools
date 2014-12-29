#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) 

require 'json'
require 'rest_client'
require 'openstack/nova'
require 'openstack/neutron'
require 'openstack/keystone'
require 'ipaddr'
require 'pp'
#"sudo gem install rest-client"

#debug puts
def dputs(message)
  puts message
end

#debug pp
def dpp(message)
  pp message
end

#info level puts
def iputs(message)
  puts message
end

#porting from neutron's iptables_firewall.py
module IptablesFirewall
protected
  CHAIN_NAME_PREFIX = {
    "ingress"      => "i",
    "egress"       => "o",
    "spoof-filter" => "s"}
  
  MAX_CHAIN_LEN_WRAP = 11
  MAX_CHAIN_LEN_NOWRAP = 28

  def _convert_sgr_to_iptables_rules(security_group_rules)
    dputs "_convert_sgr_to_iptables_rules"
    iptables_rules = []
    _drop_invalid_packets(iptables_rules)
    _allow_established(iptables_rules)

    for rule in security_group_rules
      next if rule.ethertype == "IPv6"
      args = []
      dpp rule
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
      next if args == [] && rule.direction == "ingress"
      args += ["-j RETURN"]
      dpp args.join(" ")
      iptables_rules << args.join(" ")
    end
    iptables_rules << "-j neutron-openvswi-sg-fallback"
    iptables_rules.flatten
  end

  def _spoofing_rule(port , #in
                     ipv4_rules,#out 
                     ipv4_spoofing_rules,#out
                     ipv6_rules ,#out
                     ipv6_spoofing_rules
                     )
    ipv4_rules << '-p udp -m udp --sport 68 --dport 67 -j RETURN'
    ipv4_rules << "-j #{port_to_egress_spoofing_chain_name(port)}"
    ipv4_rules << '-p udp -m udp --sport 67 --dport 68 -j DROP'
    
#    TODO: ipv6
#    ipv6_rules << ['-p icmpv6 -j RETURN']
#    ipv6_rules << ['-p udp -m udp --sport 546 --dport 547 -j RETURN']

    mac_ipv4_pairs = mac_ipv6_pairs = []  
    port.allowed_address_pairs.each do |address_pair|
      _build_ipv4v6_mac_ip_list(address_pair['mac_address'],
                                address_pair['ip_address'],
                                mac_ipv4_pairs,
                                mac_ipv6_pairs)
    end

    port.fixed_ips.each do |fixed_ip|
      _build_ipv4v6_mac_ip_list(port.mac_address, fixed_ip["ip_address"],
                                mac_ipv4_pairs, mac_ipv6_pairs)
    end
    
    if port.fixed_ips == []
      mac_ipv4_pairs << {:mac => port.mac_address, :ip => nil}
      #TODO ipv6
#      mac_ipv6_pairs << [port.mac_address, nil]
    end

    _setup_spoof_filter_chain(port, port_to_egress_chain_name(port),
                              mac_ipv4_pairs, ipv4_spoofing_rules)
#TODO: ipv6
#    _setup_spoof_filter_chain(port, port_to_egress_chain_name(port),
#                              mac_ipv4_pairs, ipv4_rules)
  end

  def _build_ipv4v6_mac_ip_list(mac, ip_address, 
                                mac_ipv4_pairs,
                                mac_ipv6_pairs)
    if IPAddr.new(ip_address).ipv4?
      mac_ipv4_pairs << {"mac" => mac, "ip" => ip_address}
    else
      mac_ipv6_pairs << {"mac" => mac, "ip" => ip_address}      
    end
  end
  
  def _setup_spoof_filter_chain(port, table, 
                                mac_ip_pairs, #in 
                                rules #out
                                )
    return unless mac_ip_pairs
    
    chain_name = _port_chain_name(port, "spoof-filter")
    #NOTICE: table name not checked

    mac_ip_pairs.each do |pair|
      if pair["ip"] == nil
        rules << "-m mac --mac-source #{pair["mac"]} -j RETURN"
      else
        rules << "-s #{pair["ip"]}/32 -m mac --mac-source #{pair["mac"]} -j RETURN"
      end
    end
    
    rules << "-j DROP"
  end

  def _port_chain_name(port, direction)
    dev = port.device_id[3..(port.device_id.size-1)]
    _get_chain_name("#{CHAIN_NAME_PREFIX[direction]}#{dev}")
  end

  def _get_chain_name(chain_name, wrap=true)
    if wrap
      return chain_name[0..MAX_CHAIN_LEN_WRAP]
    else
      return chain_name[0..MAX_CHAIN_LEN_NOWRAP]
    end
  end

  def _ip_prefix_arg(direction, ip_prefix)
    if ip_prefix
      return ["-#{direction} #{ip_prefix}"]
    else
      []
    end
  end

  def _drop_invalid_packets(iptables_rules)
    # Always drop invalid packets
    iptables_rules << ["-m state --state INVALID -j DROP"]
  end

  def _allow_established(iptables_rules)
    iptables_rules <<  ["-m state --state RELATED,ESTABLISHED -j RETURN"]
  end

  def _protocol_arg(protocol)
    return [] if protocol == nil

    iptables_rule = ["-p #{protocol}"]
    # iptables always adds '-m protocol' for udp and tcp
    if ['udp', 'tcp'].include?(protocol)
      iptables_rule += ["-m #{protocol}"]
    end

    return iptables_rule
  end

  def _port_arg(direction, protocol, 
                port_range_min, port_range_max)
    if ['udp', 'tcp', 'icmp', 'icmpv6'].include?(protocol)==false||
        port_range_min == nil
      return []
    end

    if ['icmp', 'icmpv6'].include?(protocol)
      if port_range_max != nil
        return ["--#{protocol}-type #{port_range_min}/#{port_range_max}"]
      else
        return ["--#{protocol}-type #{port_range_min}"]     
      end
    elsif port_range_min == port_range_max
      return ["--#{direction} #{port_range_min}"]
    else
      return ["-m multiport --#{direction}s #{port_range_min}:#{port_range_max}"]
    end
  end

  def implicitly_allowed_ip_own_sg(all_ports, this_port, own_sgid)
    dputs "implicitly_allowed_ip_own_sg"
    sgr = []
    #collect ingress ip address from my sg
    all_ports.select{|p| p.sgids.include?(own_sgid)}.each do |_port|
      #skip myself
      next if _port.mac_address == this_port.mac_address
      
      _port.fixed_ips.each do |ip|
        params = {"direction" => "ingress",
          "source_ip_prefix" => "#{ip["ip_address"]}/32"}
        
        dputs "item found #{_port.mac_address}, #{ip["ip_address"]}"
        sgr << SecurityGroupRule.new(params)
      end
    end
    return sgr
  end

  def allowed_ingress_rule(own_sgid)
    neutron.sgrs.list_by_sgid(own_sgid).select{|s| 
      s.direction == "ingress"}
  end

  def allowed_egress_rule(own_sgid)
    neutron.sgrs.list_by_sgid(own_sgid).select{|s| 
      s.direction == "egress"}
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

    dputs "dhcp_ports = #{dhcp_ports.inspect}"

    dhcp_ports.each do |dhcp_port|
      
      dhcp_port.fixed_ips.each do |ip|
        params = {"direction" => "ingress",
          "source_ip_prefix" => "#{ip["ip_address"]}/32",
          "protocol" => "udp",
          "source_port_range_min" => 67,
          "source_port_range_max" => 67,
          "port_range_min" => 68,
          "port_range_max" => 68}
        
        dputs "item found dhcp #{ip["ip_address"]}"
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

  def to_egress_iptable_rules(port, sgrs)
    #output rule
    out_rules = _convert_sgr_to_iptables_rules(sgrs).map do |r|
      "-A #{port_to_egress_chain_name(port)} #{r}"
    end

    #spoofing rule
    ipv4_rules = []
    ipv4_spoofing_rules = []
    ipv6_rules = []
    ipv6_spoofing_rules = []

    _spoofing_rule(port, 
                   ipv4_rules, ipv4_spoofing_rules,
                   ipv6_rules, ipv6_spoofing_rules)

    spoofing_out = ipv4_rules.map do |r|
      "-A #{port_to_egress_chain_name(port)} #{r}"
    end

    spoofing_send = ipv4_spoofing_rules.map do |r|
      "-A #{port_to_egress_spoofing_chain_name(port)} #{r}"
    end
    spoofing_out + out_rules + spoofing_send
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

  def port_to_egress_spoofing_chain_name(port)
    "neutron-openvswi-s#{port.id[0..9]}"
  end

  def iptables_data
    `sudo iptables-save`.split("\n")
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

  def delete_duplicated_rules(rules)
    out = []
    rules.each do |r|
      next if out.include?(r)
      out << r
    end
    out
  end
  
  def _check_one_port(ipt_data, port)
    dputs "=========================================="
    #collect all sgr
    all_ports = neutron.ports.list

    all_in_sgr  = []
    all_out_sgr = []

    #ingress context
    port.sgids.each do |sgid| 
      all_in_sgr += implicitly_allowed_ip_own_sg(all_ports, port, sgid)
      all_in_sgr += allowed_ingress_rule(sgid)
      all_in_sgr += implicitly_allowed_ip_remote_sg(all_ports,port, sgid)
    end

    all_in_sgr += dhcp_rules(port, all_ports)
    
    port.sgids.each do |sgid| 
      #egress context
      all_out_sgr += allowed_egress_rule(sgid)
    end

    iputs "recognized rules are..."
    iputs "[ingress]"
    in_ipt_rules = to_ingress_iptable_rules(port, all_in_sgr)
    ingress_iptables_rules = delete_duplicated_rules(in_ipt_rules)
    iputs "[egress]"
    eg_ipt_rules = to_egress_iptable_rules(port, all_out_sgr)
    egress_iptables_rules =  delete_duplicated_rules(eg_ipt_rules)

    check_rule(ingress_iptables_rules, egress_iptables_rules)
  end

  def check_rule(ingress_iptables_rules, egress_iptables_rules)
    real_iptables = `sudo iptables-save`.split("\n")
    dputs real_iptables
    dputs real_iptables.class.name
    dpp real_iptables
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
