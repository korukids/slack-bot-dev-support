require 'spec_helper'

describe SlackDevSupport::Commands::Workdays do
  describe '.call' do
    it 'shows defaults when nothing is set' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: ''))
        .to eq('<@user> works: mon, tue, wed, thu, fri')
    end

    it 'sets work-days from a comma list' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: 'mon,tue,wed,thu'))
        .to eq("<@user>'s work-days set to: mon, tue, wed, thu")
    end

    it 'sets work-days from a range' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: 'mon-thu'))
        .to eq("<@user>'s work-days set to: mon, tue, wed, thu")
    end

    it 'accepts a mix of range and comma-list tokens' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: 'mon,wed-fri'))
        .to eq("<@user>'s work-days set to: mon, wed, thu, fri")
    end

    it 'rejects unknown tokens' do
      msg = "Couldn't parse `funday`. Try a comma list (`mon,tue,wed`) or a range (`mon-thu`)."
      expect(described_class.call(channel: 'channel', user: 'user', expression: 'funday'))
        .to eq(msg)
    end

    it 'resets to default' do
      UserRegister.set_work_days(channel: 'channel', user: 'user', days: %w[mon])
      expect(described_class.call(channel: 'channel', user: 'user', expression: 'reset'))
        .to eq("<@user>'s work-days reset to default (mon-fri).")
    end

    it 'targets another user with @mention' do
      expect(described_class.call(channel: 'channel', user: 'user', expression: '<@frank> mon-tue'))
        .to eq("<@frank>'s work-days set to: mon, tue")
    end
  end
end
