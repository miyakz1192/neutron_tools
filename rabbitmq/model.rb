require 'rabbitmq/http/client'
require 'json'

class Model
  #== read
  #this methods read from json file from rabbit_mq_data(default).
  #and eliminate first key(ex: bindings) and set 
  #@#{self.class.name.downcase} (ex: @bindings)
  def read
    data = open("#{open_file_name}", "r") do |io|
      JSON.load(io)
    end["#{self.class.name.downcase}"]
    eval "@#{self.class.name.downcase} = data"
    self
  end

protected

  def open_file_name
    "rabbit_mq_data/#{self.class.name.downcase}.json"
  end
end

class Channels < Model
  attr_accessor :channels

  def connection(id)
    @channels.detect{|c| c[:id] == id}
  end

  #==inject_process
  #inject process info from Hosts(class) info to channels info
  #this method assumes that ip address in channels info is host name
  #params1::hosts. Hosts object
  #return::self
  def inject_process(hosts)
    @channels.each do |ch|
      host = hosts.detect{|h| h.host_name == ch["ip"]}
      ch["cmd"] = nil #default
      if host
        ch["cmd"] = host.find_process_by_source_port_num(ch["port"])
      end
    end
    self 
  end
end

class Consumers < Model
  attr_accessor :consumers

  def connection_of_queue(queue_name)
    con = @consumers.detect{|c| c["queue_name"] == queue_name}
    if con && con["connection"] 
      if con.class.name == "Array" && con.size > 1
        puts "WARNING: connection sizes then 1(#{con.size})"
      end
      return con["connection"].first
    end
    return {"ip" => "NOIP", "port" => "NOPORT"}
  end

  #==inject_channels
  #inject channels(class) info to consumers info
  #params1::channels, Channels object
  #return::self
  def inject_channels(channels)
    channels_info = channels.channels
#    puts "DEBUG channels first = #{channels_info}"
    @consumers.each do |co|
#      puts "DEBUG => consumer #{co}"
      channel = channels_info.select{|ch| ch["id"] == co["id"]}
#      puts "DEBUG => size = #{channel.size}"
      next unless channel
#      puts "DEBUG => channel #{channel}"
      co["connection"] = channel
    end
  end
end

class Bindings < Model
  attr_accessor :bindings

  #== find_queues_by_exchange_name
  #params1::ex_name. exchange name
  #return::array of string. queue name string array
  def find_queues_by_exchange_name(ex_name)
    @bindings.map{|b| b["destination"] if b["source"] == ex_name}.compact
  end

  def exchanges
    res = @bindings.map{|b| b["source"]}.uniq
    res.delete("")
    res
  end
end

class Host < Model
  attr_reader :host_name

  def initialize(host_name)
    @host_name = host_name
  end

  def lsof
    @host["lsof"]
  end

  def ps
    @host["ps"]
  end

  #== source_port_process
  #this method returns process that opens tcp connection
  #that source port is port(argument)
  #params1::source_port. tcp source port number.
  def find_process_by_source_port_num(source_port_num)
    temp = lsof.detect{|lsof| lsof["whole"] =~ /#{source_port_num}->/}
    return nil unless temp
    temp = ps.detect{|ps| ps["pid"] == temp["pid"]}
    return nil unless temp
    return temp["cmd"]
  end

  def open_file_name
    "rabbit_mq_data/host_#{@host_name}.json"
  end

  def self.read_hosts
    hosts = []
    Dir::glob("rabbit_mq_data/host_*.json").each do |f|
      host_name = File.basename(f).scan(/host_(.*).json/)[0][0]
      hosts << Host.new(host_name).read
    end
    hosts
  end
end

if __FILE__ == $0
  puts "reading channels"
  channels = Channels.new.read
  puts "reading consumers"
  consumers = Consumers.new.read
  puts "reading bindings"
  bindings = Bindings.new.read

  channels.inject_process(Host.read_hosts)
  consumers.inject_channels(channels)

  bindings.exchanges.each do |ex|
    puts "EXCHANGE = #{ex} and its queues"
    queues = bindings.find_queues_by_exchange_name(ex)
    queues.each do |q|
      con = consumers.connection_of_queue(q)
      puts "  QUEUE = #{q}, con=#{con["ip"]}:#{con["port"]}, cmd=#{con["cmd"]}"
    end
  end
end
