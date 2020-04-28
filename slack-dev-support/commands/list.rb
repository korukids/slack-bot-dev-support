module SlackDevSupport
  module Commands
    class List < SlackRubyBot::Commands::Base
      command 'list' do |client, data, _match|
        list = UserRegister.list(channel: data.channel)

        formatted_members = list.map{|member| "<@#{member}>"}
        joined_members = formatted_members.join(', ')

        client.say(channel: data.channel, text: "The current list is #{joined_members}")
      end
    end
  end
end
