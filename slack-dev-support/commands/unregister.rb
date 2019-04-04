module SlackDevSupport
  module Commands
    class Unregister < SlackRubyBot::Commands::Base
      command 'unregister' do |client, data, _match|
        if Redis.current.smembers(1).exclude?(data.user)
          client.say(channel: data.channel, text: "You're not registered?")
        else
          Redis.current.srem(1, data.user)
          client.say(channel: data.channel, text: "You've been removed from dev support <@#{data.user}>.")
        end
      end
    end
  end
end
 
