module RestAPIBase
  def basic_header
    {:content_type => :json, :accept => :json}    
  end
  
  def header_with_token(token)
    basic_header.merge("X-Auth-Token" => token)
  end
end
