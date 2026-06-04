require 'spec_helper'

describe SlackDevSupport::Commands::Next do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  # Give everyone a 7-day work week so eligibility doesn't depend on the day
  # the suite happens to run.
  def always_available(channel, *users)
    users.each { |u| UserRegister.set_work_days(channel:, user: u, days: UserRegister::DAY_KEYS) }
  end

  context 'when there are enough users to use the command next' do
    before do
      Redis.current.lpush('channel_users', 'user_1')
      Redis.current.lpush('channel_users', 'user_2')
      Redis.current.lpush('channel_users', 'user_3')
      always_available('channel', 'user_1', 'user_2', 'user_3')
    end

    it 'returns a prompt suggesting another user' do
      expect(message: "#{SlackRubyBot.config.user} next",
             channel: 'channel').to respond_with_slack_message('<@user_2> is on dev-support')
    end
  end

  context 'when there is only one user' do
    before do
      Redis.current.lpush('channel_users', 'user_1')
      always_available('channel', 'user_1')
    end

    it 'keeps announcing that same user' do
      expect(message: "#{SlackRubyBot.config.user} next", channel: 'channel')
        .to respond_with_slack_message('<@user_1> is on dev-support')
    end
  end
end
