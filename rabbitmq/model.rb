require 'rabbitmq/http/client'
require 'json'

class ModelReader
  def read
    file_name = "#{self.class.name.downcase}.json"
    open("rabbit_mq_data/#{file_name}") do |io|
      JSON.load(io)
    end["self.class.name.downcase"]
  end
end

class Channels
  def initialize(channels)
    @channels = channels
  end

  def connection(id)
    @channels.detect{|c| c[:id] == id}
  end
end

class Consumers
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

class Bindings

end

if __FILE__ == $0
end
