module SlackDevSupport
  class Bot < SlackRubyBot::Bot
    def self.assign
      selected = Redis.current.lrange('users', 0, 200).last

      Redis.current.set("someone_on?", false)

      $slack_client.chat_postMessage(channel: $channel, text: "<@#{selected}> is on dev support today! Is this okay?")

      sleep(250)

      unless Redis.current.get("someone_on?") == 'true'
        Redis.current.rpoplpush('users', 'users')
        $slack_client.chat_postMessage(channel: $channel, text: "I'll assume <@#{selected}> is taking over it")
      end
    end
  end
end
