require 'base64'

module Stubhub

  class Client 

    include HTTParty

    attr_accessor :access_token, :user, :sandbox
    # https://api.stubhub.com/ # login
    base_uri 'https://api.stubhub.com'

    def initialize(consumer_key, consumer_secret)
      @consumer_key = consumer_key
      @consumer_secret = consumer_secret
    end

    def login(username, password)
      post '/login', {
        grant_type: 'password',
        username: username,
        password: password
      }
    end

    def post(path, body)
      auth_hash = Base64.encode64("#{@consumer_key}:#{@consumer_secret}")
      options = {
        body: body,
        headers: {
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Authentication' => "Basic #{auth_hash}"
        }
      }
      self.class.post(path, options)
    end

  end

end
