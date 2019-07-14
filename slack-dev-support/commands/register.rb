module SlackDevSupport
  module Commands
    class Register < SlackRubyBot::Commands::Base
      command 'register' do |client, data, match|

        if !match['expression'].present?
          if Redis.current.lrange('users', 0, 200).include?(data.user)
            client.say(channel: data.channel, text: "You've already registered <@#{data.user}>!")
          else
            Redis.current.rpush('users', data.user)
            client.say(channel: data.channel, text: "Thanks for registering <@#{data.user}>!")
          end
        else
          target = match['expression'].delete('<>@')

          if Redis.current.lrange('users', 0, 200).include?(target)
            client.say(channel: data.channel, text: "<@#{target}> has already been registed!")
          else
            Redis.current.rpush('users', target)
            client.say(channel: data.channel, text: "Thanks for registering <@#{target}>!")
          end
        end
      end
    end
  end
end
