require 'spec_helper'

describe SlackDevSupport::Commands::Register do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  context 'when the user is not registered' do
    it 'registers and returns a message' do
      expect(message: "#{SlackRubyBot.config.user} register", channel: 'channel').to respond_with_slack_message('Thanks for registering <@user>!')
    end
  end

  context 'when the user is registered' do
    before do
      Redis.current.lpush('users', 'user')
    end

    it 'returns only a message' do
      expect(message: "#{SlackRubyBot.config.user} register", channel: 'channel').to respond_with_slack_message("You've already registered <@user>!")
    end
  end
end