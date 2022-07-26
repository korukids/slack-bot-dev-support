$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'dotenv'
Dotenv.load

require 'slack_dev_support_bot'
require 'web'

Thread.abort_on_exception = true

Thread.new do
  SlackDevSupport::Bot.run
rescue Exception => e
  warn "ERROR: #{e}"
  warn e.backtrace
  raise e
end

run SlackDevSupport::Web
