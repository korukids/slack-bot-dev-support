require 'dotenv'
Dotenv.load

Dir["#{File.dirname(__FILE__)}/slack-dev-support/tasks/*.rake"].each { |rake_file| load rake_file }

require_relative './slack_dev_support_bot'
