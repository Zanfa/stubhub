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

    def login(opts = {})
      if opts.include? :refresh_token?
        response = post '/login', :form, {
          grant_type: 'refresh_token',
          refresh_token: opts[:refresh_token]
        }
      else
        response = post '/login', :form, {
          grant_type: 'password',
          username: opts[:username],
          password: opts[:password]
        }
      end

      json_body = JSON.parse(response.body, {symbolize_names: true})

      # Extract important user credentials
      self.user = response.headers['X-StubHub-User-GUID']

      self.access_token = json_body[:access_token]
      self.refresh_token = json_body[:refresh_token]
      self.expires_in = json_body[:expires_in]

      # Return true if login was successful
      response.code == 200
    end
    
    def create_listing(opts = {})
      listing_params = {
          eventId: opts[:event_id],
          quantity: opts[:quantity],
          seats: opts[:seats],
          pricePerTicket: opts[:price_per_ticket],
          splitOptions: opts[:split_options].to_s.upcase.gsub('_', '')
      }

      # Optional params to support GA tickets
      listing_params[:section] = opts[:section] if opts.include? :section
      listing_params[:rows] = opts[:rows] if opts.include? :rows
      
      response = post '/inventory/listings/v1', :json, {
        listing: listing_params
      }

      if response.code == 200
        return response.parsed_response["listing"]["id"]
      end
    end

    def post(path, type, body)
      auth_hash = Base64.encode64("#{@consumer_key}:#{@consumer_secret}")

      # Enable sandboxing
      body.merge({scope: 'SANDBOX'}) if self.sandbox

      # Different headers for different requests
      headers = {}
      if type == :json
        headers['Content-Type'] = 'application/json'
        body = body.to_json
      else
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
      end

      options = {
        body: body,
        basic_auth: {
          username: @consumer_key,
          password: @consumer_secret
        },
        headers: headers
      }
      self.class.post(path, options)
    end

  end

end
