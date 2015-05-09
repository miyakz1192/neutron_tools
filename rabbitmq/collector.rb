require "json"
require 'rabbitmq/http/client'


module RemoteCommand
protected
  def rexec(cmd)
    host   = @rsc_info[:host]
    passwd = @rsc_info[:host_credential][:passwd]
    user   = @rsc_info[:host_credential][:user]

    `sshpass -p #{passwd} ssh -l #{user} -o StrictHostKeyChecking=no #{host} #{cmd}` 
  end

  def rexec_with_split(cmd)
    rexec(cmd).split("\n").map do |e|
      e.split
    end
  end
end

module RabbitMqClient
  def rabbit_mq_client
    username = @rsc_info[:api_credential][:user] 
    passwd = @rsc_info[:api_credential][:passwd] 
    RabbitMQ::HTTP::Client.new(@rsc_info[:api_endpoint],
                               :username => username,
                               :password => passwd)
  end
end

class Collector
  def initialize(params)
    @rsc_info = params.dup
  end

  def to_json
    "{}"
  end

  def write
    `mkdir rabbit_mq_data 2> /dev/null`
    open("rabbit_mq_data/#{write_file_name}", "w") do |out|
      puts "#{self.class.name}"
      out.write self.to_json
    end
  end

  def collect
    self
  end

protected

  def write_file_name
    "#{self.class.name.gsub(/Collector/, "").downcase}.json"
  end
end

class ChannelsCollector < Collector
  include RemoteCommand
  attr_reader :channels

  def collect
    temp = rexec_with_split(
      "sudo rabbitmqctl -q list_channels pid  name")
    @channels = temp.map do |c| 
      {id: c[0].gsub(/<|>/,""), 
       ip: c[1].split(":")[0],
       port: c[1].split(":")[1]}
    end
    super 
  end

  def to_json
    {channels: @channels}.to_json
  end
end

class ConsumersCollector < Collector
  include RemoteCommand
  attr_reader :consumers

  def collect
    temp = rexec_with_split("sudo rabbitmqctl -q list_consumers")
    @consumers = temp.map do |c| 
      {queue_name: c[0], id: c[1].gsub(/<|>/,"")}
    end 
    super 
  end

  #output consumers info as json format
  #{
  #    "consumers": [
  #        {
  #            "queue_name": "queue1",
  #            "id": "id1"
  #        },...
  #    ]
  #}
  def to_json
    {consumers: @consumers}.to_json
  end
end

class CollectorWithRabbitMqApi < Collector
  include RabbitMqClient

  def self.define_basic_methods(_class)
    data_source_variable_name = _class.name.gsub(/Collector/,"").downcase

    define_method(:initialize) do |params|
      super(params)
      @client = rabbit_mq_client
    end

    define_method(:collect) do
      eval "@#{data_source_variable_name} = @client.list_#{data_source_variable_name}"
      self
    end

    define_method(:to_json) do
      eval "{#{data_source_variable_name}: @#{data_source_variable_name}}.to_json"
    end
  end
end

class BindingsCollector < CollectorWithRabbitMqApi
  define_basic_methods self
end

class QueuesCollector < CollectorWithRabbitMqApi
  define_basic_methods self
end 

class HostCollector < Collector
  include RemoteCommand

  attr_reader :ps, :lsof

  def collect
    ps_temp = rexec_with_split("sudo ps -ef")
    @ps = ps_temp.map do |c|
      {pid: c[1], cmd: c.values_at(7..c.size-1).join(" ")}
    end

    lsof_temp = rexec_with_split("sudo lsof")
    @lsof = lsof_temp.map do |c|
      {pid: c[1], whole: c.join(" ")}
    end
    super
  end

  def to_json
    to_hash.to_json
  end

  def to_hash
    {host: {name: @rsc_info[:host], ps: @ps, lsof: @lsof}}
  end

protected

  def write_file_name
    "host_#{@rsc_info[:host]}.json"
  end
end

class HostsCollector < Collector

  #==collect multi hosts info
  #param1::hosts_info(Array) array of host_info array
  def collect
    @hosts_info = []
    @rsc_info.each do |hi|
      @hosts_info << HostCollector.new(hi).collect.to_hash[:host]
    end
    super
  end

  def to_json
    {hosts: @hosts_info}.to_json
  end
end

if __FILE__ == $0

  api_info   = {api_endpoint: "http://192.168.122.84:15672",
                api_credential: {user: "guest",
                                 passwd: "a"}}

  host_credential = {user: "miyakz",
                     passwd: "miyakz"}

  host_info  = {host:          "192.168.122.84",
                host_credential: host_credential}
 
  ChannelsCollector.new(host_info).collect.write
  ConsumersCollector.new(host_info).collect.write
  BindingsCollector.new(api_info).collect.write
  QueuesCollector.new(api_info).collect.write

  #host information collector
  HostsCollector.new([host_info]).collect.write

end
