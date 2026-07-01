require 'spec_helper'
require 'date'
require_relative '../../../slack-dev-support/models/support_request'

describe SupportRequest do
  let(:channel) { 'support' }
  # A fixed epoch (2026-06-10 12:00:00 UTC-ish) used as a request ts.
  let(:base_ts) { '1749556800.000100' }

  def create(ts: base_ts, user: 'U_OP', text: 'help me')
    described_class.create_request(ts:, user:, text:, channel:)
  end

  describe '.create_request' do
    it 'stores the request and indexes it as open and by day' do
      create
      req = described_class.get(ts: base_ts)
      expect(req['user']).to eq('U_OP')
      expect(req['created_at']).to eq(base_ts)
      expect(described_class.open_requests.map { |r| r['created_at'] }).to include(base_ts)
      day = Time.at(base_ts.to_f).to_date
      expect(described_class.requests_for_day(date: day).length).to eq(1)
    end

    it 'truncates the text snippet' do
      create(text: 'x' * 500)
      expect(described_class.get(ts: base_ts)['text'].length).to eq(described_class::TEXT_SNIPPET_LENGTH)
    end

    it 'is idempotent on duplicate ts' do
      create(text: 'first')
      create(text: 'second')
      expect(described_class.get(ts: base_ts)['text']).to eq('first')
    end

    it 'sets a TTL on the request hash' do
      create
      expect(Redis.current.ttl("support:req:#{base_ts}")).to be > 0
    end
  end

  describe 'transitions' do
    before { create }

    it 'marks and clears investigating' do
      described_class.mark_investigating(ts: base_ts, at: 100)
      expect(described_class.get(ts: base_ts)['investigating_at']).to eq('100')
      described_class.clear_investigating(ts: base_ts)
      expect(described_class.get(ts: base_ts)).not_to have_key('investigating_at')
    end

    it 'acknowledges, first reply wins' do
      described_class.mark_acknowledged(ts: base_ts, by: 'U_DEV', at: 200)
      described_class.mark_acknowledged(ts: base_ts, by: 'U_OTHER', at: 300)
      req = described_class.get(ts: base_ts)
      expect(req['acknowledged_at']).to eq('200')
      expect(req['acknowledged_by']).to eq('U_DEV')
    end

    it 'closes (removing from open) and reopens' do
      described_class.mark_closed(ts: base_ts, at: 400)
      expect(described_class.get(ts: base_ts)['closed_at']).to eq('400')
      expect(described_class.open_requests).to be_empty
      described_class.reopen(ts: base_ts)
      expect(described_class.get(ts: base_ts)).not_to have_key('closed_at')
      expect(described_class.open_requests.length).to eq(1)
    end

    it 'ignores transitions on unknown ts' do
      expect { described_class.mark_investigating(ts: 'nope', at: 1) }.not_to raise_error
      expect(described_class.get(ts: 'nope')).to be_nil
    end
  end

  describe '.open_requests' do
    it 'lazily drops members whose hash has expired' do
      create
      Redis.current.del("support:req:#{base_ts}") # simulate TTL expiry
      expect(described_class.open_requests).to be_empty
      expect(Redis.current.sismember('support:open', base_ts)).to be(false)
    end
  end

  describe '.metrics_for_day' do
    let(:day) { Time.at(base_ts.to_f).to_date }
    let(:created) { base_ts.to_f }

    it 'reports zero-state cleanly' do
      m = described_class.metrics_for_day(date: day)
      expect(m).to eq(count: 0, closed: 0, open: 0, avg_ack_seconds: nil, avg_close_seconds: nil)
    end

    it 'computes counts and average timings over states reached' do
      create # request A
      b_ts = (created + 10).to_s
      described_class.create_request(ts: b_ts, user: 'U_OP2', text: 'b', channel:)

      # A acknowledged after 60s, closed after 120s. B left open & unacked.
      described_class.mark_acknowledged(ts: base_ts, by: 'U_DEV', at: created + 60)
      described_class.mark_closed(ts: base_ts, at: created + 120)

      m = described_class.metrics_for_day(date: day)
      expect(m[:count]).to eq(2)
      expect(m[:closed]).to eq(1)
      expect(m[:open]).to eq(1)
      expect(m[:avg_ack_seconds]).to eq(60)
      expect(m[:avg_close_seconds]).to eq(120)
    end
  end
end
