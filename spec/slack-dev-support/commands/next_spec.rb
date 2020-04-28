require 'spec_helper'

describe SlackDevSupport::Commands::Next do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  context 'when there are enough users to use the command next' do
    before do
      Redis.current.lpush('channel_users', 'user_1')
      Redis.current.lpush('channel_users', 'user_2')
      Redis.current.lpush('channel_users', 'user_3')
    end

    it 'returns a prompt suggesting another user' do
      expect(message: "#{SlackRubyBot.config.user} next", channel: 'channel').to respond_with_slack_message("<@user_2> is on dev-support")
    end
  end

  context 'when there are not enough users to use the command next' do
    before do
      Redis.current.lpush('channel_users', 'user_1')
    end

    it 'reurns a message informing the user there are no more people to choose form' do
      expect(message: "#{SlackRubyBot.config.user} next", channel: 'channel')
        .to respond_with_slack_message("There are no more people on the list, <@user_1> is the last developer standing.")
    end
  end
end
