require 'redis'
require 'slack-ruby-client'

Dir["#{File.expand_path('config/initializers', __dir__)}/**/*.rb"].each do |file|
  require file
end

require './slack-dev-support/models/support_request'
require './slack-dev-support/models/user_register'
require './slack-dev-support/listeners/support_listener'
require './slack-dev-support/bot'
require './slack-dev-support/dispatcher'
require './slack-dev-support/socket_mode'
