require 'fog'

class OpenStackDriverFactory
  #create OpenStack Driver
  #now version only supports Fog
  #if other driver supports thease must have Fog like interface
  #@param kind [Symbol] :Network, :Identity, :Image, :Compute
  #@param auth_info [AuthInfo] authentication infomation
  def create(kind,auth_info)
    auth = convert_auth_info(auth_info)
    if kind == :Image
      auth.delete(:provider)
      Fog::Image::OpenStack::V1.new(auth)
    else
      eval("Fog::#{kind}.new(auth)")
    end
  end

protected
  # convert AuthInfo to Fog auth hash
  # @param auth_info [AuthInfo] authentication infomation
  def convert_auth_info(auth_info)
    {
      :provider => 'OpenStack',
      :openstack_api_key => auth_info.password,
      :openstack_username => auth_info.user_name,
      :openstack_auth_url => "#{auth_info.auth_url}/tokens",
      :openstack_tenant => auth_info.tenant_name
    }
  end
end
