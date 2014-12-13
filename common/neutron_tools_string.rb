class String
  def j_to_h
    JSON.parse(self)
  end
end
