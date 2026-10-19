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

  def post_top_level(channel: support, user: op, ts: req_ts, subtype: nil, bot_id: nil, text: 'help')
    described_class.handle_message(channel:, user:, text:, ts:,
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

    it 'ignores bot messages, system subtypes, and the bot itself' do
      post_top_level(bot_id: 'B1')
      post_top_level(subtype: 'channel_join')
      post_top_level(subtype: 'message_changed')
      post_top_level(user: 'U_BOT')
      expect(SupportRequest.get(ts: req_ts)).to be_nil
    end

    it 'tracks a file_share (a request raised with an attachment)' do
      post_top_level(subtype: 'file_share', text: 'here is the error screenshot')
      expect(SupportRequest.get(ts: req_ts)).not_to be_nil
    end

    it 'still ignores a file_share posted by a bot' do
      post_top_level(subtype: 'file_share', bot_id: 'B1')
      expect(SupportRequest.get(ts: req_ts)).to be_nil
    end

    it 'does not track a message that @mentions the bot (it is a command)' do
      post_top_level(text: '<@U_BOT> register')
      expect(SupportRequest.get(ts: req_ts)).to be_nil
    end

    it 'does not track a message that @mentions the bot with a label' do
      post_top_level(text: '<@U_BOT|devsupport> list')
      expect(SupportRequest.get(ts: req_ts)).to be_nil
    end

    it 'still tracks a message that mentions a different user' do
      post_top_level(text: 'hey <@U_SOMEONE> can you look at this')
      expect(SupportRequest.get(ts: req_ts)).not_to be_nil
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

  describe '#handle_deletion' do
    before { post_top_level }

    it 'stops tracking a deleted request' do
      described_class.handle_deletion(channel: support, ts: req_ts)
      expect(SupportRequest.get(ts: req_ts)).to be_nil
      expect(SupportRequest.open_requests).to be_empty
    end

    it 'ignores deletions in other channels' do
      described_class.handle_deletion(channel: other_channel, ts: req_ts)
      expect(SupportRequest.get(ts: req_ts)).not_to be_nil
    end

    it 'ignores deletions of untracked messages' do
      expect { described_class.handle_deletion(channel: support, ts: '1.0') }.not_to raise_error
      expect(SupportRequest.get(ts: req_ts)).not_to be_nil
    end
  end

  describe '#handle_reaction' do
    # What reactions.get reports is on the message, in the order Slack would
    # report it for each successive event.
    let(:slack_states) { [[]] }

    before do
      post_top_level
      allow(described_class).to receive(:current_reactions).and_return(*slack_states)
    end

    def react(action, name)
      described_class.handle_reaction(action:, name:, item_ts: req_ts, item_channel: support)
    end

    def closed?
      SupportRequest.get(ts: req_ts).key?('closed_at')
    end

    def investigating?
      SupportRequest.get(ts: req_ts).key?('investigating_at')
    end

    context 'when :eyes: is added then removed' do
      let(:slack_states) { [%w[eyes], []] }

      it 'marks then clears investigating' do
        react(:added, 'eyes')
        expect(investigating?).to be(true)
        react(:removed, 'eyes')
        expect(investigating?).to be(false)
      end
    end

    %w[white_check_mark +1 x +1::skin-tone-3].each do |emoji|
      context "when :#{emoji}: is added then removed" do
        # current_reactions folds skin tones, so Slack's state reads as plain :+1:.
        let(:slack_states) { [[emoji.sub(/::skin-tone-\d+/, '')], []] }

        it 'closes then reopens' do
          react(:added, emoji)
          expect(closed?).to be(true)
          react(:removed, emoji)
          expect(closed?).to be(false)
        end
      end
    end

    context 'when a new close reaction is added before the old one is removed' do
      let(:slack_states) { [%w[white_check_mark], %w[white_check_mark +1], %w[+1]] }

      it 'stays closed' do
        react(:added, 'white_check_mark')
        react(:added, '+1')
        react(:removed, 'white_check_mark')
        expect(SupportRequest.open_requests).to be_empty
      end
    end

    context 'when the old close reaction is removed and a different one added' do
      let(:slack_states) { [%w[white_check_mark], [], %w[heavy_check_mark]] }

      it 'ends up closed' do
        react(:added, 'white_check_mark')
        react(:removed, 'white_check_mark')
        react(:added, 'heavy_check_mark')
        expect(SupportRequest.open_requests).to be_empty
      end
    end

    context 'when a removal is checked after a quick swap already landed in Slack' do
      # The removal of the check is handled after Slack already shows the :+1:.
      let(:slack_states) { [%w[white_check_mark], %w[+1], %w[+1]] }

      it 'stays closed' do
        react(:added, 'white_check_mark')
        react(:removed, 'white_check_mark')
        react(:added, '+1')
        expect(SupportRequest.open_requests).to be_empty
      end
    end

    context 'when only unrelated reactions remain' do
      let(:slack_states) { [%w[white_check_mark], %w[eyes tada]] }

      it 'reopens' do
        react(:added, 'white_check_mark')
        react(:removed, 'white_check_mark')
        expect(SupportRequest.open_requests.length).to eq(1)
      end
    end

    context 'when someone else still has :eyes: on it' do
      let(:slack_states) { [%w[eyes], %w[eyes]] }

      it 'stays investigating' do
        react(:added, 'eyes')
        react(:removed, 'eyes')
        expect(investigating?).to be(true)
      end
    end

    context 'when Slack cannot be asked' do
      before { allow(described_class).to receive(:current_reactions).and_raise(StandardError, 'ratelimited') }

      it 'still applies an addition' do
        react(:added, 'white_check_mark')
        expect(closed?).to be(true)
      end

      it 'leaves the state alone on a removal' do
        react(:added, 'white_check_mark')
        react(:removed, 'white_check_mark')
        expect(closed?).to be(true)
      end
    end

    it 'does not ask Slack about untracked messages' do
      described_class.handle_reaction(action: :removed, name: 'x', item_ts: '1.0', item_channel: support)
      expect(described_class).not_to have_received(:current_reactions)
    end

    it 'ignores reactions in other channels' do
      described_class.handle_reaction(action: :added, name: 'eyes', item_ts: req_ts, item_channel: other_channel)
      expect(SupportRequest.get(ts: req_ts)).not_to have_key('investigating_at')
    end

    it 'ignores unrelated emoji' do
      described_class.handle_reaction(action: :added, name: 'tada', item_ts: req_ts, item_channel: support)
      req = SupportRequest.get(ts: req_ts)
      expect(req).not_to have_key('investigating_at')
      expect(req).not_to have_key('closed_at')
    end
  end

  describe '#current_reactions' do
    it 'lists the emoji on the message, skin tones folded away' do
      original = $slack_client
      $slack_client = Object.new.tap do |fake|
        fake.define_singleton_method(:reactions_get) do |**args|
          raise 'expected full: true' unless args[:full]

          { 'message' => { 'reactions' => [{ 'name' => '+1::skin-tone-2' }] } }
        end
      end
      expect(described_class.current_reactions(channel: support, ts: req_ts)).to eq(['+1'])
    ensure
      $slack_client = original
    end
  end
end
