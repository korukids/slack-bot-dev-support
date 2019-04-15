module SlackDevSupport
  module Commands
    class Yes < SlackRubyBot::Commands::Base
      command 'yes' do |client, data, _match|
        Redis.current.set("someone_on?", true)

        selected = Redis.current.lrange('users', 0, 200).last

        Redis.current.rpoplpush('users', 'users')

        members = Redis.current.lrange('not_applicable', 0, 200)

        if members.any?
          Redis.current.del('not_applicable')

          Redis.current.rpush('users', members)
        end

        client.say(channel: data.channel, text: "<@#{selected}> is on dev support today!")
      end
    end
  end
end
