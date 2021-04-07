require 'spec_helper'

describe SlackDevSupport::Commands::Register do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  context 'when the user is not registered' do
    it 'registers and returns a message' do
      expect(message: "#{SlackRubyBot.config.user} register", channel: 'channel')
        .to respond_with_slack_message('Thanks for registering <@user>!')
    end
  end

  context 'when the user is registered' do
    it 'returns only a message' do
      Redis.current.lpush('channel_users', 'user')

      expect(message: "#{SlackRubyBot.config.user} register", channel: 'channel')
        .to respond_with_slack_message("You've already registered <@user>!")
    end
  end

  context 'when multiple channels are using the bot' do
    it 'keeps a user register per channel' do
      expect(message: "#{SlackRubyBot.config.user} register", channel: 'channel1')
        .to respond_with_slack_message('Thanks for registering <@user>!')
      expect(message: "#{SlackRubyBot.config.user} register", channel: 'channel2')
        .to respond_with_slack_message('Thanks for registering <@user>!')
    end

    it 'still only allows a user to be registered once per channel' do
      Redis.current.lpush('channel1_users', 'user')
      expect(message: "#{SlackRubyBot.config.user} register", channel: 'channel1')
        .to respond_with_slack_message("You've already registered <@user>!")
    end
  end

  context 'when a user registers a different user' do
    it 'registers and returns a message' do
      expect(message: "#{SlackRubyBot.config.user} register <@user_2>", channel: 'channel')
        .to respond_with_slack_message('Thanks for registering <@user_2>!')
    end
  end
end
