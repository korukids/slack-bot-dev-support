require_relative '../models/user_register'

module SlackDevSupport
  module Commands
    class Register < SlackRubyBot::Commands::Base
      command 'register' do |client, data, match|
        target = match['expression'].present? ? match['expression'].delete('<>@') : data.user

        message = UserRegister.add(user: target, channel: data.channel)
        client.say(channel: data.channel, text: message)
      end
    end
  end
end
