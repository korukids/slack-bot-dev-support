require 'spec_helper'
require_relative '../../../slack-dev-support/listeners/support_listener'

describe SlackDevSupport::SupportListener do
  let(:support) { $channel }
  let(:other_channel) { 'C_OTHER' }
  let(:op) { 'U_OP' }
  let(:dev) { 'U_DEV' }
  let(:req_ts) { '1749556800.000100' }

  before do
    # Seed the developer roster so known_developer? recognises U_DEV.
    UserRegister.add(user: dev, channel: $channel)
    allow(described_class).to receive(:bot_user_id).and_return('U_BOT')
  end

  def post_top_level(channel: support, user: op, ts: req_ts, subtype: nil, bot_id: nil)
    described_class.handle_message(channel:, user:, text: 'help', ts:,
                                   thread_ts: nil, subtype:, bot_id:)
  end

  describe '#handle_message top-level' do
    it 'creates a request for a plain message in the support channel' do
      post_top_level
      expect(SupportRequest.get(ts: req_ts)).not_to be_nil
    end

    it 'ignores messages in other channels' do
      post_top_level(channel: other_channel)
      expect(SupportRequest.get(ts: req_ts)).to be_nil
    end

    it 'ignores bot messages, subtypes, and the bot itself' do
      post_top_level(bot_id: 'B1')
      post_top_level(subtype: 'channel_join')
      post_top_level(user: 'U_BOT')
      expect(SupportRequest.get(ts: req_ts)).to be_nil
    end
  end

  describe '#handle_message threaded reply (acknowledgement)' do
    before { post_top_level }

    def reply(user:, reply_ts: '1749556900.000200')
      described_class.handle_message(channel: support, user:, text: 'on it', ts: reply_ts,
                                     thread_ts: req_ts, subtype: nil, bot_id: nil)
    end

    it 'acknowledges when a known developer replies' do
      reply(user: dev)
      expect(SupportRequest.get(ts: req_ts)['acknowledged_by']).to eq(dev)
    end

    it 'does not acknowledge when the original poster replies' do
      reply(user: op)
      expect(SupportRequest.get(ts: req_ts)).not_to have_key('acknowledged_at')
    end

    it 'does not acknowledge when a non-developer replies' do
      reply(user: 'U_RANDOM')
      expect(SupportRequest.get(ts: req_ts)).not_to have_key('acknowledged_at')
    end
  end

  describe '#handle_reaction' do
    before { post_top_level }

    it 'eyes marks investigating, removal clears it' do
      described_class.handle_reaction(action: :added, name: 'eyes', item_ts: req_ts, item_channel: support)
      expect(SupportRequest.get(ts: req_ts)).to have_key('investigating_at')
      described_class.handle_reaction(action: :removed, name: 'eyes', item_ts: req_ts, item_channel: support)
      expect(SupportRequest.get(ts: req_ts)).not_to have_key('investigating_at')
    end

    it 'check and cross both close; removal reopens' do
      %w[white_check_mark x].each do |emoji|
        SupportRequest.reopen(ts: req_ts)
        described_class.handle_reaction(action: :added, name: emoji, item_ts: req_ts, item_channel: support)
        expect(SupportRequest.get(ts: req_ts)).to have_key('closed_at')
      end
      described_class.handle_reaction(action: :removed, name: 'x', item_ts: req_ts, item_channel: support)
      expect(SupportRequest.get(ts: req_ts)).not_to have_key('closed_at')
    end

    it 'ignores reactions in other channels' do
      described_class.handle_reaction(action: :added, name: 'eyes', item_ts: req_ts, item_channel: other_channel)
      expect(SupportRequest.get(ts: req_ts)).not_to have_key('investigating_at')
    end

    it 'ignores unrelated emoji' do
      described_class.handle_reaction(action: :added, name: 'thumbsup', item_ts: req_ts, item_channel: support)
      req = SupportRequest.get(ts: req_ts)
      expect(req).not_to have_key('investigating_at')
      expect(req).not_to have_key('closed_at')
    end
  end
end
