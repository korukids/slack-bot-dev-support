require 'redis'
require 'slack-ruby-bot'

Dir["#{File.expand_path('config/initializers', __dir__)}/**/*.rb"].each do |file|
  require file
end

require './slack-dev-support/bot'
require './slack-dev-support/commands/register'
require './slack-dev-support/commands/deregister'
require './slack-dev-support/commands/next'
require './slack-dev-support/commands/list'
