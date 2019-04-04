module SlackDevSupport
  module Commands
    class Register < SlackRubyBot::Commands::Base
      command 'register' do |client, data, _match|
        if Redis.current.lrange('users', 0, 200).include?(data.user)
          client.say(channel: data.channel, text: "You've already registered <@#{data.user}>!")
        else
          Redis.current.lpush('users', data.user)
          client.say(channel: data.channel, text: "Thanks for registering <@#{data.user}>!")
        end
      end
    end
  end
end
