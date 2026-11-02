require 'spec_helper'

describe SlackDevSupport::Schedule do
  # Build an instant from a UTC wall-clock time, then view it in the process's
  # local zone (Europe/London) — exactly what a UTC scheduler hands us.
  def utc(*args)
    Time.utc(*args).localtime
  end

  describe '.open_slot' do
    context 'when in winter (GMT, UTC+0)' do
      it 'opens assign at 09:00 UTC' do
        expect(described_class.open_slot(:assign, now: utc(2026, 11, 2, 9, 0))).to eq('09:00')
      end

      it 'stays closed at 08:00 UTC' do
        expect(described_class.open_slot(:assign, now: utc(2026, 11, 2, 8, 0))).to be_nil
      end
    end

    context 'when in summer (BST, UTC+1)' do
      it 'opens assign at 08:00 UTC' do
        expect(described_class.open_slot(:assign, now: utc(2026, 6, 10, 8, 0))).to eq('09:00')
      end

      it 'stays closed at 09:00 UTC' do
        expect(described_class.open_slot(:assign, now: utc(2026, 6, 10, 9, 0))).to be_nil
      end

      it 'opens the summary at 16:30 UTC' do
        expect(described_class.open_slot(:support_summary, now: utc(2026, 6, 10, 16, 30))).to eq('17:30')
      end
    end

    it 'handles the first weekday after clocks go back' do
      # Clocks went back Sun 25 Oct 2026.
      expect(described_class.open_slot(:assign, now: utc(2026, 10, 26, 9, 0))).to eq('09:00')
      expect(described_class.open_slot(:assign, now: utc(2026, 10, 26, 8, 0))).to be_nil
    end

    it 'handles the first weekday after clocks go forward' do
      # Clocks go forward Sun 28 Mar 2027.
      expect(described_class.open_slot(:assign, now: utc(2027, 3, 29, 8, 0))).to eq('09:00')
      expect(described_class.open_slot(:assign, now: utc(2027, 3, 29, 9, 0))).to be_nil
    end

    it 'tolerates a scheduler run starting late within the hour' do
      expect(described_class.open_slot(:assign, now: utc(2026, 11, 2, 9, 45))).to eq('09:00')
      expect(described_class.open_slot(:assign, now: utc(2026, 11, 2, 10, 0))).to be_nil
    end

    it 'matches each nudge slot' do
      expect(described_class.open_slot(:support_nudge, now: utc(2026, 11, 2, 11, 5))).to eq('11:00')
      expect(described_class.open_slot(:support_nudge, now: utc(2026, 11, 2, 15, 5))).to eq('15:00')
      expect(described_class.open_slot(:support_nudge, now: utc(2026, 11, 2, 13, 0))).to be_nil
    end

    it 'never opens at weekends' do
      expect(described_class.open_slot(:assign, now: utc(2026, 10, 31, 9, 0))).to be_nil
    end
  end

  describe '.run' do
    it 'yields once per slot even if triggered repeatedly' do
      now = utc(2026, 11, 2, 9, 0)
      calls = 0
      2.times { described_class.run(:assign, now:, force: false) { calls += 1 } }
      expect(calls).to eq(1)
    end

    it 'yields for each separate slot on the same day' do
      calls = 0
      described_class.run(:support_nudge, now: utc(2026, 11, 2, 11, 0), force: false) { calls += 1 }
      described_class.run(:support_nudge, now: utc(2026, 11, 2, 15, 0), force: false) { calls += 1 }
      expect(calls).to eq(2)
    end

    it 'does not yield outside the slot' do
      calls = 0
      described_class.run(:assign, now: utc(2026, 11, 2, 8, 0), force: false) { calls += 1 }
      expect(calls).to eq(0)
    end

    it 'always yields when forced' do
      calls = 0
      described_class.run(:assign, now: utc(2026, 10, 31, 3, 0), force: true) { calls += 1 }
      expect(calls).to eq(1)
    end
  end
end
