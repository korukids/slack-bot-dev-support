require 'spec_helper'

describe SlackDevSupport::Commands::Yes do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  before do
    Redis.current.lpush('users', 'user_1')
    Redis.current.lpush('users', 'user_2')
    Redis.current.lpush('users', 'user_3')
    Redis.current.rpoplpush('users', 'not_applicable')
  end

  it 'returns a prompt confirming the selected user' do
    expect(message: "#{SlackRubyBot.config.user} yes", channel: 'channel').to respond_with_slack_message("<@user_2> is on dev support today!")
    expect(Redis.current.lrange('users', 0, 200)).to eq(["user_2", "user_3", "user_1"])
  end 
end