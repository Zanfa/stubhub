require 'base64'
require 'json'

require 'httmultiparty'

module Stubhub

  class Client 
    include HTTMultiParty

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
          pricePerTicket: {
            amount: opts[:price_per_ticket].to_s,
            currency: 'USD'
          },
          splitOption: opts[:split_option].to_s.upcase.gsub('_', ''),
          deliveryOption: opts[:delivery_option],
          status: 'INACTIVE' # Disable for production
      }

      # Optional params to support GA tickets
      listing_params[:section] = opts[:section] if opts.include? :section
      listing_params[:rows] = opts[:rows] if opts.include? :rows
      
      response = post '/inventory/listings/v1', :json, {
        listing: listing_params
      }

      response.parsed_response["listing"]["id"]
    end

    def sales
      response = get "/accountmanagement/sales/v1/seller/#{self.user}", {
        sort: 'SALEDATE desc' 
      }

      response.parsed_response["sales"]["sale"]
    end

    def metadata(event_id)
      response = get "/catalog/events/v1/#{event_id}/metadata/inventoryMetaData", {}
      response.parsed_response["InventoryEventMetaData"]["listingAttributeList"]
      {
        traits: response.parsed_response["InventoryEventMetaData"]["listingAttributeList"],
        delivery_options: response.parsed_response["InventoryEventMetaData"]["deliveryTypeList"]
      }
    end

    def predeliver(opts = {})
      url = "/fulfillment/pdf/v1/listing/#{opts[:listing]}?seat=#{opts[:seat]}&row=#{opts[:row]}"
      response = self.class.post(url, query: {
        ticket: File.new(opts[:ticket])
      }, headers: {
        'Authorization' => "Bearer #{self.access_token}"
      })


      unless response.code == 200
        raise Stubhub::ApiError.new(response.code, response.body)
      end

      response.parsed_response
    end

    def get(path, query)
      options = {
        query: query,
        headers: {
          'Authorization' => "Bearer #{self.access_token}"
        }
      }

      response = self.class.get(path, options)
      unless response.code == 200
        raise Stubhub::ApiError.new(response.code, response.body)
      end

      response
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
        query: body,
        headers: headers
      }

      if self.access_token
        headers['Authorization'] = "Bearer #{self.access_token}"
      else
        options[:basic_auth] = {
          username: @consumer_key,
          password: @consumer_secret
        }
      end

      response = self.class.post(path, options)

      unless response.code == 200
        raise Stubhub::ApiError.new(response.code, response.body)
      end

      response
    end

  end

end
