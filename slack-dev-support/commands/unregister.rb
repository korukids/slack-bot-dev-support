module SlackDevSupport
  module Commands
    class Unregister < SlackRubyBot::Commands::Base
      command 'unregister' do |client, data, _match|
        if Redis.current.lrange('users', 0, 200).exclude?(data.user)
          client.say(channel: data.channel, text: "You're not registered?")
        else
          Redis.current.lrem('users', 1, data.user)
          client.say(channel: data.channel, text: "You've been removed from dev support <@#{data.user}>.")
        end
      end
    end
  end
end
 
