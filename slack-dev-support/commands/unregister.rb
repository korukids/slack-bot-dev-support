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

          if Redis.current.lrange('users', 0, 200).exclude?(target) && Redis.current.lrange('not_applicable', 0, 200).exclude?(target)
            client.say(channel: data.channel, text: "<@#{target}> isn't registered.")
          else
            if Redis.current.lrange('users', 0, 200).include?(target)
              Redis.current.lrem('users', 1, target)
            elsif Redis.current.lrange('not_applicable', 0, 200).include?(target)
              Redis.current.lrem('not_applicable', 1, target)
            end
              
            client.say(channel: data.channel, text: "Thanks for unregistering <@#{target}>!")
          end
        end
      end
    end
  end
end
