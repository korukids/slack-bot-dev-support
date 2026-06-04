require 'spec_helper'
require_relative '../../../slack-dev-support/commands/target_parsing'

describe SlackDevSupport::Commands::TargetParsing do
  describe '.extract_target' do
    it 'returns the default user and the full expression when no mention is present' do
      expect(described_class.extract_target('mon,tue', 'caller')).to eq(['caller', 'mon,tue'])
    end

    it 'returns the default user and an empty rest when expression is blank' do
      expect(described_class.extract_target('', 'caller')).to eq(['caller', ''])
    end

    it 'extracts a bare @mention with no trailing text' do
      expect(described_class.extract_target('<@U123>', 'caller')).to eq(['U123', ''])
    end

    it 'extracts an @mention and the remaining expression' do
      expect(described_class.extract_target('<@U123> mon-thu', 'caller')).to eq(['U123', 'mon-thu'])
    end

    it 'strips whitespace between the mention and the rest' do
      expect(described_class.extract_target("<@U123>   until 2026-06-01", 'caller'))
        .to eq(['U123', 'until 2026-06-01'])
    end

    it 'falls back to the default user when the expression starts with something else' do
      expect(described_class.extract_target('until 2026-06-01', 'caller'))
        .to eq(['caller', 'until 2026-06-01'])
    end

    it "does not extract a mention that isn't at the start" do
      expect(described_class.extract_target('mon <@U123>', 'caller'))
        .to eq(['caller', 'mon <@U123>'])
    end
  end
end
