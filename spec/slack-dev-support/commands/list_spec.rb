require 'spec_helper'

describe SlackDevSupport::Commands::List do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  before do
    Redis.current.lpush('users', 'user_1')
    Redis.current.lpush('users', 'user_2')
    Redis.current.lpush('users', 'user_3')

    Redis.current.lpush('not_applicable', 'user_4')
    Redis.current.lpush('not_applicable', 'user_5')
  end

  it 'returns only a message' do
    expect(message: "#{SlackRubyBot.config.user} list", channel: 'channel').to respond_with_slack_message("The current list is <@user_5>, <@user_4>, <@user_3>, <@user_2>, <@user_1>")
  end
end