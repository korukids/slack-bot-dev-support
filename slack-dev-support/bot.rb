module SlackDevSupport
  DEVELOPER_CHANNEL = 'GB66FUL2H'.freeze
  PRODUCT_DESIGN_CHANNEL = 'CG4VDUZ2L'.freeze

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

      command 'deregister' do
        desc 'Use this to deregister for dev-support'
        long_desc 'You can run this command with a target, for example "dev-support deregister @Frank"'
      end
    end
  end

  def self.assign_for(redis_channel:, announce_channel:, message_template:)
    # Daily rotation: tail becomes head (everyone shifts down one position).
    Redis.current.rpoplpush("#{redis_channel}_users", "#{redis_channel}_users")

    # Bring yesterday's _not_applicable bucket back into the active queue.
    yesterdays_not_applicable = Redis.current.lrange("#{redis_channel}_not_applicable", 0, 200)
    yesterdays_not_applicable.each do |user|
      Redis.current.rpush("#{redis_channel}_users", user)
    end
    Redis.current.del("#{redis_channel}_not_applicable")

    selected = Redis.current.lrange("#{redis_channel}_users", 0, 200).last
    $slack_client.chat_postMessage(channel: announce_channel,
                                   text: format(message_template, user: "<@#{selected}>"))
  end

  def self.assign
    assign_for(redis_channel: DEVELOPER_CHANNEL, announce_channel: $channel,
               message_template: '%<user>s is on dev support today!')
  end

  def self.assign_prod_design
    assign_for(redis_channel: PRODUCT_DESIGN_CHANNEL, announce_channel: $prod_design_channel,
               message_template: '%<user>s is your chair today!')
  end
end
