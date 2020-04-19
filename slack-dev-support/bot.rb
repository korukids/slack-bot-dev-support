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
    DEVELOPER_USERS_KEY = 'developer_users'
    DEVELOPER_UNAVAILABLE_USERS_KEY = 'developer_not_applicable'

    $slack_client.chat_postMessage(
      channel: $channel,
      text: "<@#{select_user(DEVELOPER_USERS_KEY, DEVELOPER_UNAVAILABLE_USERS_KEY)}> is on dev support today!"
    )
  end

  def self.assign_product_design_chair
    PRODUCT_DESIGN_USERS_KEY = 'productdesign_users'
    PRODUCT_DESIGN_USERS_UNAVAILABLE_USERS_KEY = 'productdesign_not_applicable'

    $slack_client.chat_postMessage(
      channel: $product_design_channel,
      text: "<@#{select_user(PRODUCT_DESIGN_USERS_KEY, PRODUCT_DESIGN_USERS_UNAVAILABLE_USERS_KEY)}> is the product chair today!"
    )
  end

  private

  def self.select_user(users, unavailable_users)
    Redis.current.rpoplpush(DEVELOPER_USERS_KEY, DEVELOPER_USERS_KEY)

    previously_not_applicable = Redis.current.lrange(DEVELOPER_UNAVAILABLE_USERS_KEY, 0, 200)

    previously_not_applicable.each do |user|
      Redis.current.rpush(DEVELOPER_USERS_KEY, user)
    end

    Redis.current.del(DEVELOPER_UNAVAILABLE_USERS_KEY)

    selected = Redis.current.lrange(DEVELOPER_USERS_KEY, 0, 200).last
  end
end
