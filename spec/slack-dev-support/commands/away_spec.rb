require 'spec_helper'
require 'date'

describe SlackDevSupport::Commands::Away do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  let(:future_date) { Date.today + 30 }
  let(:future) { future_date.to_s }
  let(:echoed_future) { "#{future} (#{future_date.strftime('%A %-d %B %Y')})" }

  it 'shows status when no expression given and not away' do
    expect(message: "#{SlackRubyBot.config.user} away", channel: 'channel')
      .to respond_with_slack_message('<@user> is not marked away.')
  end

  it 'shows status when no expression given and already away' do
    UserRegister.set_away_until(channel: 'channel', user: 'user', date: future_date)
    expect(message: "#{SlackRubyBot.config.user} away", channel: 'channel')
      .to respond_with_slack_message("<@user> is away until #{future}.")
  end

  it 'sets away until a future date and echoes the resolved date' do
    expect(message: "#{SlackRubyBot.config.user} away until #{future}", channel: 'channel')
      .to respond_with_slack_message("<@user> marked away until #{echoed_future}.")
  end

  it 'rejects dates in the past' do
    past_date = Date.today - 1
    past = past_date.to_s
    expect(message: "#{SlackRubyBot.config.user} away until #{past}", channel: 'channel')
      .to respond_with_slack_message("That date (#{past}) is in the past.")
  end

  it 'clears an away flag' do
    UserRegister.set_away_until(channel: 'channel', user: 'user', date: Date.today + 5)
    expect(message: "#{SlackRubyBot.config.user} away clear", channel: 'channel')
      .to respond_with_slack_message('<@user> is no longer marked away.')
  end

  it 'targets another user' do
    expect(message: "#{SlackRubyBot.config.user} away <@frank> until #{future}", channel: 'channel')
      .to respond_with_slack_message("<@frank> marked away until #{echoed_future}.")
  end

  it 'rejects gibberish' do
    expect(message: "#{SlackRubyBot.config.user} away soon", channel: 'channel')
      .to respond_with_slack_message('Couldn\'t parse `soon`. Try `until 2026-06-01` or `clear`.')
  end
end
