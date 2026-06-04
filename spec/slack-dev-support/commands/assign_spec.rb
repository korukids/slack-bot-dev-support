require 'spec_helper'

describe SlackDevSupport::Commands::Assign do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  context 'self-assign (no expression)' do
    before do
      Redis.current.rpush('channel_users', 'user')
      Redis.current.rpush('channel_users', 'other')
    end

    it 'assigns caller and displaces previous' do
      msg = '<@user> is on dev-support'
      expect(message: "#{SlackRubyBot.config.user} assign", channel: 'channel')
        .to respond_with_slack_message(msg)
    end
  end

  context "self-assign with 'me'" do
    before do
      Redis.current.rpush('channel_users', 'user')
      Redis.current.rpush('channel_users', 'other')
    end

    it 'assigns caller' do
      msg = '<@user> is on dev-support'
      expect(message: "#{SlackRubyBot.config.user} assign me", channel: 'channel')
        .to respond_with_slack_message(msg)
    end
  end

  context 'targeting another user' do
    before do
      Redis.current.rpush('channel_users', 'frank')
      Redis.current.rpush('channel_users', 'other')
    end

    it 'assigns the target' do
      msg = '<@frank> is on dev-support'
      expect(message: "#{SlackRubyBot.config.user} assign <@frank>", channel: 'channel')
        .to respond_with_slack_message(msg)
    end
  end

  context 'already on duty' do
    before do
      Redis.current.rpush('channel_users', 'other')
      Redis.current.rpush('channel_users', 'user') # tail
    end

    it 'reports no-op' do
      expect(message: "#{SlackRubyBot.config.user} assign", channel: 'channel')
        .to respond_with_slack_message('<@user> is already on dev-support today.')
    end
  end

  context 'unregistered' do
    it 'rejects' do
      expect(message: "#{SlackRubyBot.config.user} assign", channel: 'channel')
        .to respond_with_slack_message('<@user> is not registered. Use `register` first.')
    end
  end
end
