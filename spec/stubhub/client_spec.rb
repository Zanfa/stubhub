require 'spec_helper'

describe Stubhub::Client do
  let(:consumer_key) { 'foo_key' }
  let(:consumer_secret) { 'foo_secret' }
  let(:user_guid) { 'bar' }
  let(:access_token) { 'foo' }

  it 'initializes with credentials' do
    stubhub = Stubhub::Client.new(consumer_key, consumer_secret)
    stubhub.should be
  end

  it 'allows adding user credentials' do
    stubhub = Stubhub::Client.new(consumer_key, consumer_secret)
    stubhub.user = user_guid
    stubhub.access_token = access_token
  end

  it 'allows setting sandbox' do
    stubhub = Stubhub::Client.new(consumer_key, consumer_secret)
    stubhub.sandbox = true
  end

  context 'logging in' do

    let(:stubhub) { Stubhub::Client.new(consumer_key, consumer_secret) }
    let(:username) { 'user' }
    let(:password) { 'pass' }

    it 'calls API to log in' do
      stub = stub_request(:post, "https://#{consumer_key}:#{consumer_secret}@api.stubhub.com/login").with(
        body: {
          grant_type: 'password',
          username: username,
          password: password
        },
        headers: {
          'Content-Type' => 'application/x-www-form-urlencoded',
        }
      ).to_return(status: 200, body: '{}')

      stubhub.login({
        username: username,
        password: password
      })

      stub.should have_been_requested
    end

    it 'updates user credentials upon successful login' do
      access_token = 'foo_access_token'
      refresh_token = 'bar_refresh_token'
      user_guid = 'foobar_user_guid'
      expires_in = '1234567890'

      stub_request(:post, /.*/)
        .to_return(status: 200, body: {
          token_type: 'bearer',
          expires_in: expires_in,
          refresh_token: refresh_token,
          access_token: access_token
      }.to_json, headers: {
          'Content-Type' => 'application/json',
          'X-StubHub-User-GUID' => user_guid
        })

      stubhub.login(username: username, password: password)

      stubhub.access_token.should eq(access_token)
      stubhub.user.should eq(user_guid)
      stubhub.refresh_token.should eq(refresh_token)
      stubhub.expires_in.should eq(expires_in)
    end

    it 'updates user credential using refreh token' do
      stub_request(:post, /.*/)
        .to_return(status: 200, body: {
          token_type: 'bearer',
          expires_in: 'expires_in',
          refresh_token: 'new_refresh_token',
          access_token: 'new_access_token'
      }.to_json, headers: {
          'Content-Type' => 'application/json',
          'X-StubHub-User-GUID' => user_guid
      })

      stubhub.login(refresh_token: 'refresh_token')

      stubhub.access_token.should eq('new_access_token')
    end

    it 'returns true for a successful login false for unsuccessful' do
      stub_request(:post, /.*/)
        .to_return(status: 200, body: '{}')
        .to_return(status: 403, body: '{}')

      stubhub.login(username: username, password: password).should be_true
      stubhub.login(username: username, password: password).should be_false
    end

  end

  context ".create_listing" do

    let(:stubhub) { 
      stubhub = Stubhub::Client.new(consumer_key, consumer_secret) 
      stubhub.user = 'userid'
      stubhub.access_token = 'access_token'
      stubhub
    }

    let (:valid_response) {
      {
        status: 200,
        headers: {
          'Content-Type' => 'application/json'
        },
        body: {
          listing: {
            id: 123123
          }
        }.to_json
      }
    }

    it "creates listing from hash" do
      create_listing_request = stub_request(:post, /.+\/inventory\/listings\/v1$/)
        .with(body: {listing: {
          eventId: "123",
          quantity: 5,
          section: "Section A",
          rows: "14",
          seats: "2,3,4,5,6",
          pricePerTicket: 123.25,
          splitOptions: "NOSINGLES"
        }}, headers: {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer access_token'
        })
        .to_return(valid_response)

      stubhub.create_listing({
        event_id: '123',
        quantity: 5,
        section: "Section A",
        rows: "14",
        seats: "2,3,4,5,6",
        price_per_ticket: 123.25,
        split_options: :no_singles
      })

      expect(create_listing_request).to have_been_requested
    end

    it "works with GA" do

      create_listing_request = stub_request(:post, /.+\/inventory\/listings\/v1$/)
        .with(body: {listing: {
          eventId: "124",
          quantity: 3,
          seats: "1,2,3",
          pricePerTicket: 123.25,
          splitOptions: "NOSINGLES"
        }}, headers: {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer access_token'
        })
        .to_return(valid_response)

      stubhub.create_listing({
        event_id: '124',
        quantity: 3,
        price_per_ticket: 123.25,
        split_options: :no_singles,
        seats: "1,2,3" # Make up seat numbers for GA
      })

      expect(create_listing_request).to have_been_requested
    end

    it "returns id" do
      stub_request(:post, /.*/)
        .to_return(valid_response)

      listing_id = stubhub.create_listing({})
      expect(listing_id).to eq(123123)
    end

  end

  context ".sales" do 
    
  end

end
