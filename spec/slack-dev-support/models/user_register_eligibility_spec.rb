require 'spec_helper'
require 'date'
require_relative '../../../slack-dev-support/models/user_register'

describe UserRegister do
  let(:channel) { 'channel_1' }
  let(:user) { 'user_1' }

  describe '.work_days' do
    it 'defaults to mon-fri when unset' do
      expect(described_class.work_days(channel:, user:)).to eq(%w[mon tue wed thu fri])
    end

    it 'returns stored days' do
      described_class.set_work_days(channel:, user:, days: %w[mon tue])
      expect(described_class.work_days(channel:, user:)).to eq(%w[mon tue])
    end

    it 'reset restores default' do
      described_class.set_work_days(channel:, user:, days: %w[mon])
      described_class.reset_work_days(channel:, user:)
      expect(described_class.work_days(channel:, user:)).to eq(%w[mon tue wed thu fri])
    end
  end

  describe '.eligible?' do
    it 'returns true for a default user on a weekday' do
      expect(described_class.eligible?(channel:, user:, date: Date.new(2026, 5, 20))).to be(true) # Wed
    end

    it 'returns false on a non-work-day' do
      described_class.set_work_days(channel:, user:, days: %w[mon tue])
      expect(described_class.eligible?(channel:, user:, date: Date.new(2026, 5, 20))).to be(false) # Wed
    end
  end

  describe '.advance_until_eligible' do
    before do
      Redis.current.rpush("#{channel}_users", 'user_a')
      Redis.current.rpush("#{channel}_users", 'user_b')
      Redis.current.rpush("#{channel}_users", 'user_c') # tail = today's pick
    end

    it 'returns the tail when eligible' do
      result = described_class.advance_until_eligible(channel:, date: Date.new(2026, 5, 20))
      expect(result).to eq('user_c')
    end

    it 'rotates an ineligible tail to the head of the list' do
      described_class.set_work_days(channel:, user: 'user_c', days: %w[mon tue])
      result = described_class.advance_until_eligible(channel:, date: Date.new(2026, 5, 20)) # Wed
      expect(result).to eq('user_b')
      expect(described_class.list_active(channel:)).to eq(%w[user_c user_a user_b])
    end

    it 'returns nil and leaves the list unchanged when no-one is eligible' do
      %w[user_a user_b user_c].each do |u|
        described_class.set_work_days(channel:, user: u, days: %w[sun])
      end
      expect(described_class.advance_until_eligible(channel:, date: Date.new(2026, 5, 20))).to be_nil
      expect(described_class.list_active(channel:)).to eq(%w[user_a user_b user_c])
    end
  end

  describe '.remove' do
    it 'clears the user metadata hash too' do
      described_class.add(user:, channel:)
      described_class.set_work_days(channel:, user:, days: %w[mon tue])
      described_class.remove(user:, channel:)
      expect(Redis.current.hgetall("#{channel}_user:#{user}")).to be_empty
    end
  end
end
