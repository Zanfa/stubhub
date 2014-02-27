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
    let(:auth_hash) { 'Zm9vX2tleTpmb29fc2VjcmV0' }

    it 'calls API to log in' do

      stub_request(:post, 'https://api.stubhub.com/login').with(
        body: {
          grant_type: 'password',
          username: username,
          password: password
        },
        headers: {
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Authentication' => "Basic #{auth_hash}"
        }
      )

      stubhub.login(username, password)
    end

  end

end
