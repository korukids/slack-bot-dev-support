$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

# Load environment variables
require 'dotenv'
Dotenv.load('.env.test')

require 'pry'

require 'slack_dev_support_bot'

RSpec.configure do |config|
  # Keep Socket Mode's stdout logging out of the test output.
  SlackDevSupport::SocketMode.instance_variable_set(:@logger, Logger.new(File::NULL))

  # Safety net: the suite flushes its Redis DB, so refuse to run against the
  # default DB 0 (where dev/prod data lives). .env.test points at DB 15.
  db = Redis.current.connection[:db]
  if db.zero?
    raise 'Refusing to run specs against Redis DB 0 — set REDIS_URL in .env.test ' \
          'to a dedicated DB (e.g. redis://localhost:6379/15).'
  end

  # Flush before AND after each example so no fixture leaks past the suite into
  # the shared Redis server.
  config.before { Redis.current.flushdb }
  config.after { Redis.current.flushdb }
end
