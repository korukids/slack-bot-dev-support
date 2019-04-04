module SlackDevSupport
  module Commands
    class No < SlackRubyBot::Commands::Base
      command 'no' do |client, data, _match|
        members = Redis.current.lrange('users', 0, 200)

        Redis.current.rpoplpush('users', 'not_applicable')

        client.say(channel: data.channel, text: "That's fine, how about <@#{members.second}>?")
      end
    end
  end
end

