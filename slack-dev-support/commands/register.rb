module SlackDevSupport
  module Commands
    class Register < SlackRubyBot::Commands::Base
      command 'register' do |client, data, match|
        redis_user_key = "#{data.channel}_users"

        if !match['expression'].present?
          if Redis.current.lrange(redis_user_key, 0, 200).include?(data.user)
            client.say(channel: data.channel, text: "You've already registered <@#{data.user}>!")
          else
            Redis.current.lpush(redis_user_key, data.user)
            client.say(channel: data.channel, text: "Thanks for registering <@#{data.user}>!")
          end
        else
          target = match['expression'].delete('<>@')

          if Redis.current.lrange(redis_user_key, 0, 200).include?(target)
            client.say(channel: data.channel, text: "<@#{target}> has already been registed!")
          else
            Redis.current.lpush(redis_user_key, target)
            client.say(channel: data.channel, text: "Thanks for registering <@#{target}>!")
          end
        end
      end
    end
  end
end
