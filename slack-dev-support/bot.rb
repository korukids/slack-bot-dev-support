module SlackDevSupport
  class Bot < SlackRubyBot::Bot
    help do
      title 'dev-support bot'
      desc 'This bot assigns a dev to the dev-support channel every morning'

      command 'next' do
        desc 'This tells the bot to assign dev-support to the next person on the list'
        long_desc 'You can run this command at any time during the day, and it will move the current dev-support user to tomorrow and pick the next person in the rotation for today. You can run this until there are no more users to take over for today.'
      end

      command 'list' do
        desc 'This lists all the users in dev-support'
      end

      command 'register' do
        desc 'Use this to register for dev-support'
        long_desc 'You can run this command with a target, for example "dev-support register @Frank"'
      end

      command 'unregister' do
        desc 'Use this to unregister for dev-support'
        long_desc 'You can run this command with a target, for example "dev-support unregister @Frank"'
      end
    end
  end

  def self.assign
    Redis.current.rpoplpush('users', 'users')

    yesterdays_not_applicable = Redis.current.lrange('not_applicable', 0, 200)

    yesterdays_not_applicable.each do |user|
      Redis.current.rpush('users', user)
    end

    Redis.current.del('not_applicable')

    selected = Redis.current.lrange('users', 0, 200).last

    $slack_client.chat_postMessage(channel: $channel, text: "<@#{selected}> is on dev support today!")
  end
end
