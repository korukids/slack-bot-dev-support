require_relative '../models/user_register'

module SlackDevSupport
  module Commands
    class List < SlackRubyBot::Commands::Base
      command 'list' do |client, data, _match|
        list = UserRegister.list(channel: data.channel)

        formatted_members = list.map do |member|
          work_days = UserRegister.work_days(channel: data.channel, user: member)
          if work_days == UserRegister::DEFAULT_WORK_DAYS
            "<@#{member}>"
          else
            "<@#{member}> (works #{work_days.join('/')})"
          end
        end

        client.say(channel: data.channel, text: "The current list is #{formatted_members.join(', ')}")
      end
    end
  end
end
