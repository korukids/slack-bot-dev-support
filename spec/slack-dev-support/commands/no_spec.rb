require 'spec_helper'

describe SlackDevSupport::Commands::No do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  before do
    Redis.current.lpush('users', 'user_1')
    Redis.current.lpush('users', 'user_2')
    Redis.current.lpush('users', 'user_3')
  end

  it 'returns a prompt suggesting another user' do
    expect(message: "#{SlackRubyBot.config.user} no", channel: 'channel').to respond_with_slack_message("That's fine, how about <@user_2>?")
  end 
end