#has not used in this system yet.
class OpenStackObjectModel
  def initialize(params)
    raise ArgumentError.new, "params must be hash, but params is #{params.class.name}" unless params.is_a?(Hash)
    @myself = params
  end

  def method_missing(name, *args)
    key = name.to_s
#    super if @myself[key] == nil
    return @myself[key]
  end
end
