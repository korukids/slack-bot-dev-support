module SlackDevSupport
  module Commands
    class List < SlackRubyBot::Commands::Base
      command 'list' do |client, data, _match|
        members = Redis.current.lrange('users', 0, 200)

        not_applicable_members = Redis.current.lrange('not_applicable', 0, 200)

        all_members = not_applicable_members + members

        formatted_members = all_members.map{|member| "<@#{member}>"}

        joined_members = formatted_members.join(', ')

        client.say(channel: data.channel, text: "The current list is #{joined_members}")
      end
    end
  end
end
