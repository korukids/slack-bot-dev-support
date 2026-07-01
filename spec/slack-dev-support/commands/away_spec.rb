require 'spec_helper'
require 'date'

describe SlackDevSupport::Commands::Away do
  describe '.call' do
    let(:future_date) { Date.today + 30 }
    let(:future) { future_date.to_s }
    let(:echoed_future) { "#{future} (#{future_date.strftime('%A %-d %B %Y')})" }

    it 'shows status when no expression given and not away' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: ''))
        .to eq('<@user> is not marked away.')
    end

    it 'shows status when no expression given and already away' do
      UserRegister.set_away_until(channel: 'channel', user: 'user', date: future_date)
      expect(described_class.call(channel: 'channel', user: 'user', expression: ''))
        .to eq("<@user> is away until #{future}.")
    end

    it 'sets away until a future date and echoes the resolved date' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: "until #{future}"))
        .to eq("<@user> marked away until #{echoed_future}.")
    end

    it 'rejects dates in the past' do
      past_date = Date.today - 1
      past = past_date.to_s
      expect(described_class.call(channel: 'channel', user: 'user', expression: "until #{past}"))
        .to eq("That date (#{past}) is in the past.")
    end

    it 'clears an away flag' do
      UserRegister.set_away_until(channel: 'channel', user: 'user', date: Date.today + 5)
      expect(described_class.call(channel: 'channel', user: 'user', expression: 'clear'))
        .to eq('<@user> is no longer marked away.')
    end

    it 'targets another user' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: "<@frank> until #{future}"))
        .to eq("<@frank> marked away until #{echoed_future}.")
    end

    it 'rejects gibberish' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: 'soon'))
        .to eq('Couldn\'t parse `soon`. Try `until 2026-06-01` or `clear`.')
    end
  end
end
