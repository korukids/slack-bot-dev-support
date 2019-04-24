require 'redis'
require 'slack-ruby-bot'

Dir[File.expand_path('config/initializers', __dir__) + '/**/*.rb'].each do |file|
  require file
end

require './slack-dev-support/bot'
require './slack-dev-support/commands/register'
require './slack-dev-support/commands/unregister'
require './slack-dev-support/commands/set_time'
require './slack-dev-support/commands/no'
require './slack-dev-support/commands/yes'
require './slack-dev-support/commands/rotate'
require './slack-dev-support/commands/list'

