module SlackDevSupport
  module Commands
    class Next < SlackRubyBot::Commands::Base
      help do
        command 'next' do
          desc 'This tells the bot to assign dev-support to the next person on the list'
          long_desc 'You can run this command at any time during the day, and it will move the current dev-support user to tomorrow and pick the next person in the rotation for today. You can run this until there are no more users to take over for today.'
        end
      end

      command 'next' do |client, data, _match|
        users_key = "#{data.channel}_users"
        not_available_users_key = "#{data.channel}_not_applicable"

        if Redis.current.lrange(users_key, 0, 200).count > 1
          Redis.current.rpoplpush(users_key, not_available_users_key)

          members = Redis.current.lrange(users_key, 0, 200)

          client.say(channel: data.channel, text: "<@#{members.last}> is on dev-support")
        else
          last_dev_standing = Redis.current.lrange(users_key, 0, 200).last
          client.say(
            channel: data.channel,
            text: "There are no more people on the list, <@#{last_dev_standing}> is the last developer standing."
          )
        end
      end
    end
  end
end
