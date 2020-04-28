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
        next_user = UserRegister.skip(channel: data.channel)

        if next_user
          client.say(channel: data.channel, text: "<@#{next_user}> is on dev-support")
        else
          last_dev_standing = UserRegister.list(channel: data.channel).last
          client.say(
            channel: data.channel,
            text: "There are no more people on the list, <@#{last_dev_standing}> is the last developer standing."
          )
        end
      end
    end
  end
end
