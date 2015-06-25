require 'base64'
require 'json'
require 'uri'
require 'net/https'
require 'httmultiparty'

module Stubhub

  class Client
    include HTTMultiParty

    # http_proxy 'localhost', 8888
    if ENV["STUBHUB_PROXY"]
      uri = URI.parse(ENV["STUBHUB_PROXY"])
      http_proxy uri.host, uri.port, uri.user, uri.password
    end

    attr_accessor :access_token, :refresh_token, :expires_in, :user, :sandbox

    base_uri 'https://api.stubhub.com'

    def initialize(consumer_key, consumer_secret)
      @consumer_key = consumer_key
      @consumer_secret = consumer_secret
    end

    def login(opts = {})
      @access_token = nil

      # if opts.include? :refresh_token?
      #   response = post '/login', :form, {
      #     grant_type: 'refresh_token',
      #     refresh_token: opts[:refresh_token]
      #   }
      # else
        response = post '/login', :form, {
          grant_type: 'password',
          username: opts[:username],
          password: opts[:password]
        }
      # end

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
      url = "/inventory/listings/v1"


      listing_params = {
          eventId: opts[:event_id],
          quantity: opts[:quantity],
          seats: opts[:seats],
          pricePerTicket: {
            amount: opts[:price_per_ticket].to_s,
            currency: 'USD'
          },
          deliveryOption: opts[:delivery_option],
          ticketTraits: [],
          rows: opts[:rows],
          section: opts[:section],
          # status: 'INACTIVE' # Disable for production
      }

      opts[:traits].each do |trait|
        listing_params[:ticketTraits].push({id: trait.to_s})
      end

      if opts[:split_option] == -1
        listing_params[:splitOption] = 'NOSINGLES'
      elsif opts[:split_option] == 0
        listing_params[:splitOption] = 'NONE'
      else
        listing_params[:splitOption] = 'MULTIPLES'
        listing_params[:splitQuantity] = opts[:split_option]
      end

      if opts[:in_hand_date]
        listing_params[:inhandDate] = opts[:in_hand_date]
      end

      if opts.include? :tickets
         url = "/inventory/listings/v1/barcodes"
         listing_params[:tickets] = opts[:tickets]
      end

      response = post url, :json, {
        listing: listing_params
      }

      response.parsed_response["listing"]["id"]
    end

    def delete_listing(stubhub_id)
      response = delete "/inventory/listings/v1/#{stubhub_id}"
      response.parsed_response["listing"]["id"]
    end

    def update_listing(stubhub_id, listing={})

      if listing.include? :traits
        listing[:ticketTraits] = []

        listing[:traits].each do |trait|
          listing[:ticketTraits].push({id: trait.to_s})
        end

        listing.delete :traits
      end

      if listing.include? :split_option
        if listing[:split_option] == -1
          listing[:splitOption] = 'NOSINGLES'
        elsif listing[:split_option] == 0
          listing[:splitOption] = 'NONE'
        else
          listing[:splitOption] = 'MULTIPLES'
          listing[:splitQuantity] = listing[:split_option]
        end

        listing.delete :split_option
      end

      if listing.include? :price
        listing[:pricePerTicket] = {
          amount: listing[:price],
          currency: 'USD'
        }

        listing.delete :price
      end

      if listing.include? :memo
        listing[:internalNotes] = listing[:memo]

        listing.delete :memo
      end

      response = put "/inventory/listings/v1/#{stubhub_id}", {
        listing: listing
      }

      response.parsed_response["listing"]["id"]
    end

    def sales(options = {})
      params = {
        sort: 'SALEDATE desc'
      }

      filters = []

      if options.include? :listing_ids
        filters.push "LISTINGIDS:#{options[:listing_ids].join(',')}"
      end

      if options.include? :status
        filters.push "STATUS:#{options[:status].to_s.upcase}"
      end

      unless filters.empty?
        params[:filters] = filters.join(" AND ")
      end

      response = get "/accountmanagement/sales/v1/seller/#{self.user}", params
      response.parsed_response["sales"]["sale"]
    end

    def metadata(event_id)
      response = get "/catalog/events/v1/#{event_id}/metadata/inventoryMetaData", {}
      {
        isVenueScrubbed: response.parsed_response["InventoryEventMetaData"]["isVenueScrubbed"],
        traits: response.parsed_response["InventoryEventMetaData"]["listingAttributeList"],
        delivery_options: response.parsed_response["InventoryEventMetaData"]["deliveryTypeList"],
        fee: response.parsed_response["InventoryEventMetaData"]["eventDetail"]["deliveryFeePerTicket"]
      }
    end

    def predeliver_barcodes(listing_id, seats)
      tickets = []

      seats.each do |seat|
        tickets.push({
            row: seat[:row],
            seat: seat[:seat],
            barcode: seat[:barcode]
          })
      end
      tickets.to_json
      response = post "/inventory/listings/v1/#{listing_id}/barcodes", :json, {
        listing: {
          tickets: tickets
        }
      }

      response.parsed_response
    end
    
     # job for fulfill barcode for tickets
    def deliver_barcodes(order_id, seats)
    puts order_id
    ticket_seat = []
    seats.each do |seat|
        ticket_seat.push({
            row: seat[:row],
            seat: seat[:seat],
            barcode: seat[:barcode],
            type: seat[:type]
          })
      end
      params = { orderId: order_id, ticketSeat: ticket_seat }
      options = params.to_json
      response = post "/fulfillment/barcode/v1/order/", :json, options
      response.parsed_response
    end

    def predeliver(opts = {})

      url = "/fulfillment/pdf/v1/listing/#{opts[:listing]}?seat=#{opts[:seat]}&row=#{opts[:row]}"
      url = URI.encode(url)
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

    def deliver(opts = {})

      data = {
        orderId: opts[:order_id],
        ticketSeat: []
      }

      params = {}

      headers = {
        'Authorization' => "Bearer #{self.access_token}",
        parts: {
          json: {
            'Content-Type' => 'application/json',
          }
        }
      }

      opts[:seats].each_with_index do |seat, i|
        file_name = File.basename(seat[:file])
        data[:ticketSeat].push({
          row: seat[:row],
          seat: seat[:seat],
          fileName: file_name
        })

        params["file_#{i}"] = UploadIO.new(File.new(seat[:file]), 'application/pdf', file_name)
      end

      params[:json] = data.to_json

      url = URI.parse('https://api.stubhub.com/fulfillment/pdf/v1/order')
      req = Net::HTTP::Post::Multipart.new url.path, params, headers

      proxy_uri = URI.parse(ENV["STUBHUB_PROXY"])
      http = Net::HTTP.new(url.host, url.port, proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
      http.use_ssl = url.port == 443

      response = http.start { |http| http.request(req) }

      unless response.code == "200"
        raise Stubhub::ApiError.new(response.code, response.body)
      end

      JSON.parse(response.body)
    end
    
    def get_airbill(order_id)
      url = "/fulfillment/shipping/v1/labels"
      body = { orderId: order_id }
      response = post(url, :json , body)
      response.parsed_response
      response["labelContent"]
    end

    def sections(event_id)
      url = "/search/inventory/v1/sectionsummary"
      response = get(url, {"eventId" => event_id})
      response.parsed_response["section"]
    end

    def get_listing(listing_id)
      url = "/accountmanagement/listings/v1/#{listing_id}"
      response = get(url, {})

      response.parsed_response["listing"]
    end

    def get_listings(opts = {})
      filter = "STATUS:ACTIVE"
      if opts[:inactive]
        filter = "STATUS:INACTIVE"
      end

      url = "/accountmanagement/listings/v1/seller/#{@user}"
      response = get(url, {
        start: opts[:start] || 0,
        filters: filter
      })

      response.parsed_response["listings"]["listing"]
    end

    def get_price(opts = {})
      priceRequest = {
        amountPerTicket: {
          currency: "USD",
          amount: opts[:price]
        },
        listingSource: "StubHubPro"
      }

      if opts[:type] == :listing_price
        priceRequest[:amountType] = "LISTING_PRICE"
      else
        priceRequest[:amountType] = "DISPLAY_PRICE"
      end

      if opts[:stubhub_id]
        priceRequest = priceRequest.merge({
          listingId: opts[:stubhub_id],
        })
      else
        priceRequest = priceRequest.merge({
          eventId: opts[:event_id],
          section: opts[:section],
          row: opts[:row],
          fulfillmentType: opts[:delivery_option]
        })
      end

      body = {
        priceRequestList: {
          priceRequest: [priceRequest]
        }
      }

      url = "/pricing/aip/v1/price"
      response = post(url, :json, body)


      if opts[:type] == :listing_price
        return response.parsed_response["priceResponseList"]
          .andand["priceResponse"].andand[0].andand["displayPrice"].andand["amount"]
      else
        return response.parsed_response["priceResponseList"]
          .andand["priceResponse"].andand[0].andand["listingPrice"].andand["amount"]
      end
    end

    def search_event(q, from, to, start, limit)
      date_format = "%Y-%m-%dT%H:%M"
      from = Time.new(from.year, from.month, from.day, 0, 0)
      to = Time.new(to.year, to.month, to.day, 23, 59)
      query = {
        q: q,
        date: "#{from.strftime(date_format)} TO #{to.strftime(date_format)}",
        start: start,
        limit: limit,
        status: ["active", "contingent"],
        sort: "dateLocal asc"
      }

      response = get("/search/catalog/events/v2", query)

      response.parsed_response
    end
    # method to get ingetratedEventInd for an event from stubhub
    def event_integrated(eventId)
      response = get("/catalog/events/v2/#{eventId}", "")
      response.parsed_response["event"]["integratedEventInd"]
    end

    def get(path, query)
      options = {
        query: query,
        headers: {
          'Authorization' => "Bearer #{self.access_token}"
        }
      }

      puts "Requested: #{self.class.base_uri}/#{path} with: #{options.to_json}"

      response = self.class.get(path, options)
      unless response.code == 200
        raise Stubhub::ApiError.new(response.code, response.body)
      end

      response
    end

    def put(path, body)
      headers = {
        'Content-Type' => 'application/json'
      }

      options = {
        query: body.to_json,
        headers: headers
      }

      puts "Stubhub PUT #{self.class.base_uri}/#{path} with: #{body}"
      headers['Authorization'] = "Bearer #{self.access_token}"

      response = self.class.put(path, options)
      puts "Stubhub PUT response #{response.body}"

      unless response.code == 200
        raise Stubhub::ApiError.new(response.code, response.body)
      end

      puts "Stubhub PUT response #{response.body}"

      response
    end

    def delete(path)
      headers = {
        'Content-Type' => 'application/json'
      }

      options = {
        headers: headers
      }

      headers['Authorization'] = "Bearer #{self.access_token}"

      response = self.class.delete(path, options)

      unless response.code == 200
        raise Stubhub::ApiError.new(response.code, response.body)
      end

      puts "Stubhub DELETE response #{response.body}"

      response
    end

    def post(path, type, body)
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

      puts "Stubhub POST #{path} #{options}"

      response = self.class.post(path, options)

      unless response.code == 200
        raise Stubhub::ApiError.new(response.code, response.body)
      end

      puts "Stubhub POST response #{response.body}"

      response
    end

  end

end
