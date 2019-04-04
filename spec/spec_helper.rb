$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

require 'slack-ruby-bot/rspec'
require 'slack_dev_support_bot'

RSpec.configure do |config|
  config.before(:each) do
    Redis.current.flushdb
  end
end