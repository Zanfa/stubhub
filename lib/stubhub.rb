require "stubhub/version"
require 'httparty'

module Stubhub

  autoload :Client, 'stubhub/client'

  def self.new(consumer_key, consumer_secret)
    Stubhub::Client.new(consumer_key, consumer_secret)
  end

end
