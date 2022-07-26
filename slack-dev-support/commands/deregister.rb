require_relative '../models/user_register'

module SlackDevSupport
  module Commands
    class Deregister < SlackRubyBot::Commands::Base
      command 'deregister' do |client, data, match|
        if match['expression'].present?
          target = match['expression'].delete('<>@')
          bot_response = UserRegister.remove(user: target, channel: data.channel)
        else
          bot_response = UserRegister.remove(user: data.user, channel: data.channel)
        end
        client.say(channel: data.channel, text: bot_response)
      end
    end
  end
end
