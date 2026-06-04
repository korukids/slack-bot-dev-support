require 'spec_helper'

describe SlackDevSupport::Commands::Workdays do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  it 'shows defaults when nothing is set' do
    expect(message: "#{SlackRubyBot.config.user} workdays", channel: 'channel')
      .to respond_with_slack_message('<@user> works: mon, tue, wed, thu, fri')
  end

  it 'sets work-days from a comma list' do
    expect(message: "#{SlackRubyBot.config.user} workdays mon,tue,wed,thu", channel: 'channel')
      .to respond_with_slack_message("<@user>'s work-days set to: mon, tue, wed, thu")
  end

  it 'sets work-days from a range' do
    expect(message: "#{SlackRubyBot.config.user} workdays mon-thu", channel: 'channel')
      .to respond_with_slack_message("<@user>'s work-days set to: mon, tue, wed, thu")
  end

  it 'accepts a mix of range and comma-list tokens' do
    expect(message: "#{SlackRubyBot.config.user} workdays mon,wed-fri", channel: 'channel')
      .to respond_with_slack_message("<@user>'s work-days set to: mon, wed, thu, fri")
  end

  it 'rejects unknown tokens' do
    msg = "Couldn't parse `funday`. Try a comma list (`mon,tue,wed`) or a range (`mon-thu`)."
    expect(message: "#{SlackRubyBot.config.user} workdays funday", channel: 'channel')
      .to respond_with_slack_message(msg)
  end

  it 'resets to default' do
    UserRegister.set_work_days(channel: 'channel', user: 'user', days: %w[mon])
    expect(message: "#{SlackRubyBot.config.user} workdays reset", channel: 'channel')
      .to respond_with_slack_message("<@user>'s work-days reset to default (mon-fri).")
  end

  it 'targets another user with @mention' do
    expect(message: "#{SlackRubyBot.config.user} workdays <@frank> mon-tue", channel: 'channel')
      .to respond_with_slack_message("<@frank>'s work-days set to: mon, tue")
  end
end
