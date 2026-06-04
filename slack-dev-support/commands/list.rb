require 'date'
require_relative '../models/user_register'

module SlackDevSupport
  module Commands
    class List < SlackRubyBot::Commands::Base
      command 'list' do |client, data, _match|
        list = UserRegister.list(channel: data.channel)

        formatted_members = list.map do |member|
          notes = []

          away = UserRegister.away_until(channel: data.channel, user: member)
          notes << "away until #{away}" if away && away >= Date.today

          work_days = UserRegister.work_days(channel: data.channel, user: member)
          notes << "works #{work_days.join('/')}" if work_days != UserRegister::DEFAULT_WORK_DAYS

          notes.empty? ? "<@#{member}>" : "<@#{member}> (#{notes.join('; ')})"
        end

        client.say(channel: data.channel, text: "The current list is #{formatted_members.join(', ')}")
      end
    end
  end
end
