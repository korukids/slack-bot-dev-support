require 'spec_helper'

describe SlackDevSupport::Commands::Unregister do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  context 'when the user is not registered' do
    it 'tells the user they are not registered' do
      expect(message: "#{SlackRubyBot.config.user} unregister", channel: 'channel')
        .to respond_with_slack_message("You're not registered?")
    end
  end

  context 'when the user is registered' do
    before do
      Redis.current.lpush('users', 'user')
    end

    it 'it unregisters them and returns a message' do
      expect(message: "#{SlackRubyBot.config.user} unregister", channel: 'channel')
        .to respond_with_slack_message("You've been removed from dev support <@user>.")
    end
  end
end
