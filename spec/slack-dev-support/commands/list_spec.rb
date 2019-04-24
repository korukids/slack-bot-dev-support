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
  end

  it 'returns only a message' do
    expect(message: "#{SlackRubyBot.config.user} list", channel: 'channel').to respond_with_slack_message("The current rotation is <@user_1>, <@user_2>, <@user_3>")
  end
end