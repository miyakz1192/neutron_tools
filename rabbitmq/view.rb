require "#{File.dirname(__FILE__)}/model"

puts "loading channels"
channels = RabbitModel::ChannelContainer.new.load
puts "loading consumers"
consumers = RabbitModel::ConsumerContainer.new.load
puts "loading bindings"
bindings = RabbitModel::BindingContainer.new.load
puts "loading queues"
queues = RabbitModel::QueueContainer.new.load
puts "loading hosts"
hosts = RabbitModel::HostContainer.new.load

puts "normalize infomation(inject_process)"
channels.inject_process(hosts)
puts "normalize infomation(inject_channels)"
consumers.inject_channels(channels)

puts "analyzing"
bindings.exchange_names.each do |ex|
  puts "EXCHANGE = #{ex} and its queues"
  qnames = bindings.find_queue_names_by_exchange_name(ex)
  qnames.each do |qn|
    ch = consumers.find_channel_by_queue_name(qn)
    b = queues.find_by_name(qn).backing_queue_status
    puts "  QUEUE = #{qn}, len=#{b["len"]}, ch=#{ch.ip}:#{ch.port}, cmd=#{ch.cmd}"
  end
end
