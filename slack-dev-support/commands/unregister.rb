module SlackDevSupport
  module Commands
    class Unregister < SlackRubyBot::Commands::Base
      command 'unregister' do |client, data, match|
        users_key = "#{data.channel}_users"
        unavailable_users_key = "#{data.channel}_not_applicable"

        if !match['expression'].present?
          if Redis.current.lrange(users_key, 0, 200).exclude?(data.user)
            client.say(channel: data.channel, text: "You're not registered?")
          else
            Redis.current.lrem(users_key, 1, data.user)
            client.say(channel: data.channel, text: "You've been removed from dev support <@#{data.user}>.")
          end
        else
          target = match['expression'].delete('<>@')

          if Redis.current.lrange(users_key, 0, 200).exclude?(target) && Redis.current.lrange(unavailable_users_key, 0, 200).exclude?(target)
            client.say(channel: data.channel, text: "<@#{target}> isn't registered.")
          else
            if Redis.current.lrange(users_key, 0, 200).include?(target)
              Redis.current.lrem(users_key, 1, target)
            elsif Redis.current.lrange(unavailable_users_key, 0, 200).include?(target)
              Redis.current.lrem(unavailable_users_key, 1, target)
            end
              
            client.say(channel: data.channel, text: "Thanks for unregistering <@#{target}>!")
          end
        end
      end
    end
  end
end
