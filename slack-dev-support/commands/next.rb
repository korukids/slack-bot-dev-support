require_relative '../models/user_register'

module SlackDevSupport
  module Commands
    class Next < SlackRubyBot::Commands::Base
      help do
        command 'next' do
          desc 'This tells the bot to assign dev-support to the next person on the list'
          long_desc 'You can run this command at any time during the day, and it will move the current dev-support user on and pick the next person in the rotation for today. Users whose work-days exclude today are skipped automatically.'
        end
      end

      command 'next' do |client, data, _match|
        next_user = UserRegister.skip(channel: data.channel)

        text = next_user ? "<@#{next_user}> is on dev-support" : 'No-one is available for dev-support today.'
        client.say(channel: data.channel, text:)
      end
    end
  end
end
