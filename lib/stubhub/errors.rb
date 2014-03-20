module Stubhub

  class ApiError < StandardError 

    attr_accessor :code, :body

    def initialize(code=0, body=nil)
      super "Error code: #{code} Body: #{body}"
      @code = code
      @body = body
    end
  end

end
