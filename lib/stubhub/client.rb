require 'base64'
require 'json'

module Stubhub

  class Client 
    include HTTParty

    attr_accessor :access_token, :refresh_token, :expires_in, :user, :sandbox

    base_uri 'https://api.stubhub.com'

    def initialize(consumer_key, consumer_secret)
      @consumer_key = consumer_key
      @consumer_secret = consumer_secret
    end

    def login(username, password)
      response = post '/login', {
        grant_type: 'password',
        username: username,
        password: password
      }

      json_body = JSON.parse(response.body, {symbolize_names: true})

      # Extract important user credentials
      self.user = response.headers['X-StubHub-User-GUID']

      self.access_token = json_body[:access_token]
      self.refresh_token = json_body[:refresh_token]
      self.expires_in = json_body[:expires_in]

      # Return true if login was successful
      response.code == 200
    end

    def sales
      get("/accountmanagement/sales/v1/seller/#{self.user}")[:sales]
    end

    def get(path)

      options = {
        headers: {
          # Notice the Bearer instead of Basic
          'Authorization' => "Bearer #{self.access_token}"
        }
      }

      response = self.class.get(path, options)
      JSON.parse(response.body, {symbolize_names: true})
    end

    def post(path, body)

      # Enable sandboxing
      body.merge({scope: 'SANDBOX'}) if self.sandbox

      options = {
        body: body,
        basic_auth: {
          username: @consumer_key,
          password: @consumer_secret
        },
        headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      }
      self.class.post(path, options)
    end

  end

end
