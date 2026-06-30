$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

# Load environment variables
require 'dotenv'
Dotenv.load('.env.test')

require 'pry'

require 'slack_dev_support_bot'

RSpec.configure do |config|
  # Keep Socket Mode's stdout logging out of the test output.
  SlackDevSupport::SocketMode.instance_variable_set(:@logger, Logger.new(File::NULL))

  config.before do
    Redis.current.flushdb
  end
end
