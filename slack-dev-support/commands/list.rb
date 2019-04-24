module SlackDevSupport
  module Commands
    class List < SlackRubyBot::Commands::Base
      command 'list' do |client, data, _match|
        members = Redis.current.lrange('users', 0, 200)

        formatted_members = members.map{|member| "<@#{member}>"}.reverse

        joined_members = formatted_members.join(', ')

        client.say(channel: data.channel, text: "The current rotation is #{joined_members}")
      end
    end
  end
end

