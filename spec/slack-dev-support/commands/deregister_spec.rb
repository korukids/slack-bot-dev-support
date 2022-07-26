require 'spec_helper'

describe SlackDevSupport::Commands::Deregister do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  context 'when the user is provided' do
    before do
      Redis.current.lpush('users_users', 'user')
    end

    it 'removes the user' do
      expect(message: "#{SlackRubyBot.config.user} deregister <@user>", channel: 'users')
        .to respond_with_slack_message('<@user> has been deregistered')
    end
  end

  context 'when the user is deregistering themselves' do
    before do
      Redis.current.lpush('users_users', 'user')
    end

    it 'deregisters them and returns a message' do
      expect(message: "#{SlackRubyBot.config.user} deregister", channel: 'users')
        .to respond_with_slack_message('<@user> has been deregistered')
    end
  end
end
