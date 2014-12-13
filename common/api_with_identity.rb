class APIWithIdendity
  attr_reader :ip_address, :port
  attr_reader :keystone

  #params[:ip_address] neutron api endpoint
  #params[:port] neutron api endpoint port
  #params[:ketstone] keystone object
  def initialize(params)
    @ip_address = params[:ip_address]
    @port = params[:port]
    @keystone = params[:keystone]
  end
end
