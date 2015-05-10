require 'rabbitmq/http/client'
require 'json'
require 'ostruct'

module RabbitModel
class Model < OpenStruct
end

class Channel < Model
end

class Queue <  Model
end

class Consumer <  Model
end

class Binding < Model
end

class Host < Model
  #== source_port_process
  #this method returns process that opens tcp connection
  #that source port is port(argument)
  #params1::source_port. tcp source port number.
  def find_process_by_tcp_sport_num(tcp_sport_num)
    temp = self.lsof.detect{|lsof| lsof["whole"] =~ /#{tcp_sport_num}->/}
    return nil unless temp
    temp = self.ps.detect{|ps| ps["pid"] == temp["pid"]}
    return nil unless temp
    return temp["cmd"]
  end
end

class ModelContainer
  #== read
  #this methods read from json file from rabbit_mq_data(default).
  #and eliminate first key(ex: bindings) and set 
  #@#{self.class.name.downcase} (ex: @bindings)
  def load
    data = open(open_file_name, "r") do |io|
      JSON.load(io)
    end[models_name]
    build_models(data)
    self
  end

protected

  def model_name
    "#{self.class.name}".gsub(/Container|RabbitModel::/,"")
  end

  def models_name
    "#{model_name.downcase}s"
  end

  def build_models(data)
    eval("@#{models_name} = data.map{|d| #{model_name}.new(d)}")
    #example: @channels = data.map{|d| Channel.new(d)}
  end

  def open_file_name
    "rabbit_mq_data/#{models_name}.json"
  end
end

class ChannelContainer < ModelContainer

  def find_by_id(id)
    @channels.detect{|c| c.id == id}
  end

  #==inject_process
  #inject process info from Hosts(class) info to channels info
  #this method assumes that ip address in channels info is host name
  #params1::hosts. Hosts object
  #return::self
  def inject_process(host_container)
    @channels.each do |ch|
      host = host_container.find_by_channel(ch)
      next unless host
      ch.cmd = host.find_process_by_tcp_sport_num(ch.port)
    end
    self 
  end
end

class ConsumerContainer < ModelContainer

  def find_channel_by_queue_name(queue_name)
    con = @consumers.select{|c| c.queue_name == queue_name}
    if con.size == 1
      return con.first.channel
    elsif con.size == 0
      return Channel.new({ip: "NOIP", port: "NOPORT"})
    elsif con.size > 1
      puts "WARNING: connection sizes then 1(#{con.size})"
      return con.first.channel
    end
  end

  #==inject_channels
  #inject channels(class) info to consumers info
  #params1::channels, Channels object
  #return::self
  def inject_channels(channel_container)
    @consumers.each do |co|
      channel = channel_container.find_by_id(co.id)
      next unless channel
      co.channel = channel
    end
  end
end

class BindingContainer < ModelContainer

  #== find_queues_by_exchange_name
  #params1::ex_name. exchange name
  #return::array of string. queue name string array
  def find_queue_names_by_exchange_name(ex_name)
    @bindings.map{|b| b.destination if b.source == ex_name}.compact
  end

  def exchange_names
    res = @bindings.map{|b| b.source}.uniq
    res.delete("")
    res
  end
end

class QueueContainer < ModelContainer
  def find_by_name(queue_name)
    @queues.detect{|q| q.name == queue_name}
  end
end

class HostContainer < ModelContainer
  def find_by_channel(ch)
    @hosts.detect{|h| h.name == ch.ip}
  end
end

end
