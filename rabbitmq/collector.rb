
class Collector
  def initialize(params)
    @host   = params[:host]
    @user   = params[:user]
    @passwd = params[:passwd]
    @credential = params.dup
  end

  def to_json
    "{}"
  end

protected

  def rexec(cmd)
    `sshpass -p #{@passwd} ssh -l #{@user} -o StrictHostKeyChecking=no #{@host} #{cmd}` 
  end

end

class ChannelsCollector < Collector
  def collect
    temp = rexec("sudo rabbitmqctl -q list_channels pid  name").split("\n").map do |e|
      e.split
    end
    @channels = temp.map do |c| 
      {id: c[0].gsub(/<|>/,""), 
       ip: c[1].split(":")[0],
       port: c[1].split(":")[1]}
    end
    self 
  end

  def to_json
    {channels: @channels}.to_json
  end
end

class ConsumersCollector < Collector
  def collect
    temp = `sudo rabbitmqctl -q list_consumers`.split("\n").map do |e|
      e.split
    end
    @channels = ChannelsCollector.new(@credential).collect
    @consumers = temp.map do |c| 
      queue_name = c[0]
      id = c[1].gsub(/<|>/,"")
      {queue_name: queue_name, 
       id: id,
       connection: @channels.connection(id)}
    end 
    self
  end

  #output consumers info as json format
  #{
  #    "consumers": [
  #        {
  #            "queue": "queue1",
  #            "id": "id1"
  #        },
  #        {
  #            "queue": "queue2",
  #            "id": "id2"
  #        }
  #    ]
  #}
  def to_json
    {consumers: @consumers}.to_json
  end
end


if __FILE__ == $0

  credential = {host: "192.168.122.84",
                user: "miyakz",
                passwd: "miyakz"}

  puts ChannelsCollector.new(credential).collect

end
