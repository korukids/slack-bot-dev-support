require 'spec_helper'

describe SlackDevSupport::Commands::Rotate do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  before do
    Redis.current.lpush('users', 'user_1')
    Redis.current.lpush('users', 'user_2')
    Redis.current.lpush('users', 'user_3')
    Redis.current.lpush('users', 'user_4')
  end

  it 'returns only a message' do
    expect(message: "#{SlackRubyBot.config.user} rotate", channel: 'channel').to respond_with_slack_message("New rotation is <@user_2>, <@user_3>, <@user_4>, <@user_1>")
  end
end