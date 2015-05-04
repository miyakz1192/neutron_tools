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
    file_name = self.class.name.gsub(/Collector/, "").downcase
    open("rabbit_mq_data/#{file_name}.json", "w") do |out|
      puts "#{self.class.name}"
      out.write self.to_json
    end
  end

  def collect
    self
  end
end

class ChannelsCollector < Collector
  include RemoteCommand
  attr_reader :channels

  def collect
    temp = rexec("sudo rabbitmqctl -q list_channels pid  name").split("\n").map do |e|
      e.split
    end
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
    temp = rexec("sudo rabbitmqctl -q list_consumers").split("\n").map do |e|
      e.split
    end
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

class BindingsCollector < Collector
  include RabbitMqClient
  attr_reader :bindings

  def initialize(params)
    super(params)
    @client = rabbit_mq_client
  end

  def collect
    @bindings = @client.list_bindings
    super 
  end

  def to_json
    {bindings: @bindings}.to_json
  end
end 

if __FILE__ == $0

  api_info   = {api_endpoint: "http://192.168.122.84:15672",
                api_credential: {user: "guest",
                                 passwd: "a"}}

  host_info  = {host:          "192.168.122.84",
                host_credential:{user: "miyakz",     
                                 passwd: "miyakz"}}
 
  ChannelsCollector.new(host_info).collect.write
  ConsumersCollector.new(host_info).collect.write
  BindingsCollector.new(api_info).collect.write
end
