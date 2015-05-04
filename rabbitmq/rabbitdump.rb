require 'rabbitmq/http/client'
require 'json'

class RabbitChannels
  def initialize(channels)
    @channels = channels
  end

  def connection(id)
    @channels.detect{|c| c[:id] == id}
  end
end

class RabbitConsumers

  def initialize(consumers)
    @consumers = consumers
  end

  def find_consumers_by_queue(queue_name)
    @consumers.select{|c| c[:queue_name] == queue_name}
  end

  def consumers_on_queue
    res = []
    @consumers.map{|c| c[:queue_name]}.uniq.each do |queue_name|
      consumers = @consumers.select{|c| c[:queue_name] == queue_name}
      res << {queue: queue_name, consumers: consumers}
    end
    res
  end

  def multi_consumers_on_queue?
    consumers_on_queue.any?{|e| e[:consumers].size > 1}
  end
end

class RabbitData
  def initialize(params)
    @exchanges = params[:exchanges]
    @bindings = params[:bindings]
    @queues = params[:queues]
    @consumers = params[:consumers]
  end

  def find_exchange_by_name(name)
    @exchanges.detect{|e| e.name == name}
  end

  def draw(exchange_name)
    puts "exchange -> queue"
    @bindings.select{|b| b.source == exchange_name}.each do |b|
      puts "#{b.source} -> #{b.destination}"
    end
    
    queues = @bindings.map{|b| 
      b.destination if b.source == exchange_name}.compact
  end
end

if __FILE__ == $0
  #exp codes
  endpoint = "http://192.168.122.84:15672"
  client = RabbitMQ::HTTP::Client.new(endpoint, :username => "guest", :password => "a")
  puts client.list_bindings
=begin  
  rabbit = RabbitData.new(:exchanges => client.list_exchanges,
                          :bindings => client.list_bindings,
                          :queues => client.list_queues,
                          :consumers => RabbitConsumers.new.collect)
  
  rabbit.draw("neutron")
  
  cons = RabbitConsumers.new.collect
  cons.collect
  puts "===1"
  puts cons.find_consumers_by_queue("l3_agent")
  puts "===2"
  puts cons.consumers_on_queue
  puts "===3"
  puts cons.multi_consumers_on_queue?
  
  puts "===4"
  chan = RabbitChannels.new.collect
  puts chan.connection("rabbit@icehouse01.1.1035.0")
=end
end
