require 'rabbitmq/http/client'
require 'json'

class Model
  #== read
  #this methods read from json file from rabbit_mq_data(default).
  #and eliminate first key(ex: bindings) and set 
  #@#{self.class.name.downcase} (ex: @bindings)
  def read
    file_name = "#{self.class.name.downcase}.json"
    data = open("rabbit_mq_data/#{file_name}", "r") do |io|
      JSON.load(io)
    end["#{self.class.name.downcase}"]
    eval "@#{self.class.name.downcase} = data"
    self
  end
end

class Channels < Model
  attr_accessor :channels

  def connection(id)
    @channels.detect{|c| c[:id] == id}
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

if __FILE__ == $0
  puts "reading channels"
  channels = Channels.new.read
  puts "reading consumers"
  consumers = Consumers.new.read
  puts "reading bindings"
  bindings = Bindings.new.read

  consumers.inject_channels(channels)

  bindings.exchanges.each do |ex|
    puts "EXCHANGE = #{ex} and its queues"
    queues = bindings.find_queues_by_exchange_name(ex)
    queues.each do |q|
      con = consumers.connection_of_queue(q)
      puts "  QUEUE = #{q} #{con["ip"]}:#{con["port"]}" 
    end
  end
end
