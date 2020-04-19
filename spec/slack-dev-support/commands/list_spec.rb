require 'spec_helper'

describe SlackDevSupport::Commands::List do
  CHANNEL_NAME = 'channel'
  USERS_KEYS = "#{CHANNEL_NAME}_users"
  UNAVAILABLE_USERS_KEY = "#{CHANNEL_NAME}_not_applicable"

  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  before do
    Redis.current.lpush(USERS_KEYS, 'user_1')
    Redis.current.lpush(USERS_KEYS, 'user_2')
    Redis.current.lpush(USERS_KEYS, 'user_3')

    Redis.current.lpush(UNAVAILABLE_USERS_KEY, 'user_4')
    Redis.current.lpush(UNAVAILABLE_USERS_KEY, 'user_5')
  end

  it 'returns only a message' do
    expect(message: "#{SlackRubyBot.config.user} list", channel: CHANNEL_NAME)
      .to respond_with_slack_message("The current list is <@user_5>, <@user_4>, <@user_3>, <@user_2>, <@user_1>")
  end
end
