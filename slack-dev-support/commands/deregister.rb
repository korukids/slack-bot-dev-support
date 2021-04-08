require_relative '../models/user_register'

module SlackDevSupport
  module Commands
    class Deregister < SlackRubyBot::Commands::Base
      command 'deregister' do |client, data, match|
        if !match['expression'].present?
          bot_response = UserRegister.remove(user: data.user, channel: data.channel)
          client.say(channel: data.channel, text: bot_response)
        else
          target = match['expression'].delete('<>@')
          bot_response = UserRegister.remove(user: target, channel: data.channel)
          client.say(channel: data.channel, text: bot_response)
        end
      end
    end
  end
end
