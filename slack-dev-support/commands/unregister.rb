module SlackDevSupport
  module Commands
    class Unregister < SlackRubyBot::Commands::Base
      command 'unregister' do |client, data, match|

        if !match['expression'].present?
          if Redis.current.lrange('users', 0, 200).exclude?(data.user)
            client.say(channel: data.channel, text: "You're not registered?")
          else
            Redis.current.lrem('users', 1, data.user)
            client.say(channel: data.channel, text: "You've been removed from dev support <@#{data.user}>.")
          end
        else
          target = match['expression'].delete('<>@')

          if Redis.current.lrange('users', 0, 200).exclude?(target)
            client.say(channel: data.channel, text: "<@#{target}> isn't registered.")
          else
            Redis.current.lrem('users', 1, target)
            client.say(channel: data.channel, text: "Thanks for unregistering <@#{target}>!")
          end
        end
      end
    end
  end
end
