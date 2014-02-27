require 'spec_helper'

describe Stubhub do

  let (:consumer_key) { 'consumer_key' }
  let (:consumer_secret) { 'consumer_secret' }

  it 'initializes with valid credentials' do
    stubhub = Stubhub.new(consumer_key, consumer_secret)

    stubhub.should be
  end

end
