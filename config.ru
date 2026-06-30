$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'dotenv'
Dotenv.load

require 'slack_dev_support_bot'
require 'web'

Thread.abort_on_exception = true

# The Socket Mode runtime runs its own EventMachine reactor, so it lives on a
# background thread while Sinatra serves the (trivial) web process in front.
Thread.new do
  SlackDevSupport::SocketMode.run
rescue Exception => e
  warn "ERROR: #{e}"
  warn e.backtrace
  raise e
end

run SlackDevSupport::Web
