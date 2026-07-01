require 'spec_helper'
require_relative '../../slack-dev-support/dispatcher'

describe SlackDevSupport::Dispatcher do
  let(:bot_id) { 'UBOT' }

  describe '.dispatch' do
    it 'routes a command after the leading mention' do
      expect(described_class.dispatch(text: '<@UBOT> register', channel: 'channel', user: 'user', bot_id:))
        .to eq('Thanks for registering <@user>!')
    end

    it 'passes the remaining expression through to the handler' do
      expect(described_class.dispatch(text: '<@UBOT> register <@frank>', channel: 'channel', user: 'user', bot_id:))
        .to eq('Thanks for registering <@frank>!')
    end

    it 'tolerates a labelled mention "<@UBOT|devsupport>"' do
      expect(described_class.dispatch(text: '<@UBOT|devsupport> list', channel: 'channel', user: 'user', bot_id:))
        .to eq('The current list is ')
    end

    it 'is case-insensitive on the command word' do
      expect(described_class.dispatch(text: '<@UBOT> LIST', channel: 'channel', user: 'user', bot_id:))
        .to eq('The current list is ')
    end

    it 'returns help text for `help`' do
      expect(described_class.dispatch(text: '<@UBOT> help', channel: 'channel', user: 'user', bot_id:))
        .to include('dev-support bot')
    end

    it 'returns help text for a bare mention' do
      expect(described_class.dispatch(text: '<@UBOT>', channel: 'channel', user: 'user', bot_id:))
        .to include('dev-support bot')
    end

    it 'reports unknown commands' do
      expect(described_class.dispatch(text: '<@UBOT> frobnicate', channel: 'channel', user: 'user', bot_id:))
        .to eq('Sorry, I don\'t know the command `frobnicate`. Try `help`.')
    end

    it 'ignores messages not addressed to the bot' do
      expect(described_class.dispatch(text: 'just chatting in the channel', channel: 'channel', user: 'user', bot_id:))
        .to be_nil
    end

    it 'ignores a mention of someone else' do
      expect(described_class.dispatch(text: '<@USOMEONE> register', channel: 'channel', user: 'user', bot_id:))
        .to be_nil
    end
  end
end
