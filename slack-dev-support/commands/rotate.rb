module SlackDevSupport
  module Commands
    class Rotate < SlackRubyBot::Commands::Base
      command 'rotate' do |client, data, _match|
        Redis.current.rpoplpush('users', 'users')

        members = Redis.current.lrange('users', 0, 200)

        formatted_members = members.map{|member| "<@#{member}>"}.reverse

        joined_members = formatted_members.join(', ')

        client.say(channel: data.channel, text: "New rotation is #{ joined_members }")
      end
    end
  end
end

