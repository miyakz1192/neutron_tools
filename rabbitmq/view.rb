require "#{File.dirname(__FILE__)}/model"

puts "reading channels"
channels = Channels.new.read
puts "reading consumers"
consumers = Consumers.new.read
puts "reading bindings"
bindings = Bindings.new.read

puts "normalize infomation(inject_process)"
channels.inject_process(Host.read_hosts)
puts "normalize infomation(inject_channels)"
consumers.inject_channels(channels)

puts "analyzing"
bindings.exchanges.each do |ex|
  puts "EXCHANGE = #{ex} and its queues"
  queues = bindings.find_queues_by_exchange_name(ex)
  queues.each do |q|
    con = consumers.connection_of_queue(q)
    puts "  QUEUE = #{q}, con=#{con["ip"]}:#{con["port"]}, cmd=#{con["cmd"]}"
  end
end
