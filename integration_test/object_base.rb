class ObjectBase
  def initialize(params = {})
    @logger = Logger.new(STDOUT)
  end

protected
  def logger
    @logger
  end
end
