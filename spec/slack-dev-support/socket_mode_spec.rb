require 'spec_helper'

describe SlackDevSupport::SocketMode do
  describe '.handle_message_event (command dispatch gating)' do
    let(:bot_id) { 'UBOT' }

    # $channel comes from .env.test (CHANNEL_ID). Build a top-level human
    # message event addressed to the bot, in the given channel.
    def command_event(channel:)
      {
        'type' => 'message',
        'channel' => channel,
        'user' => 'U_HUMAN',
        'text' => '<@UBOT> list',
        'ts' => '1.0',
        'thread_ts' => nil,
        'subtype' => nil
      }
    end

    before do
      # Don't touch the listener's own logic or the network here — we're only
      # asserting whether command dispatch fires.
      allow(SlackDevSupport::SupportListener).to receive(:handle_message)
      allow(described_class).to receive(:post)
      allow(SlackDevSupport::Dispatcher).to receive(:dispatch).and_return('a reply')
    end

    it 'dispatches and posts for a message in the support channel' do
      described_class.handle_message_event(command_event(channel: $channel), bot_id)

      expect(SlackDevSupport::Dispatcher).to have_received(:dispatch).with(hash_including(channel: $channel))
      expect(described_class).to have_received(:post).with(channel: $channel, text: 'a reply')
    end

    it 'dispatches commands from another channel, targeting the main-channel roster' do
      described_class.handle_message_event(command_event(channel: 'C_OTHER'), bot_id)

      # The command operates on $channel's state...
      expect(SlackDevSupport::Dispatcher).to have_received(:dispatch).with(hash_including(channel: $channel))
      # ...but the reply goes back to where it was typed.
      expect(described_class).to have_received(:post).with(channel: 'C_OTHER', text: 'a reply')
    end

    it 'still forwards every message to the listener regardless of channel' do
      described_class.handle_message_event(command_event(channel: 'C_OTHER'), bot_id)

      expect(SlackDevSupport::SupportListener)
        .to have_received(:handle_message).with(hash_including(channel: 'C_OTHER'))
    end
  end

  describe '.backoff_seconds' do
    it 'grows with the attempt number and is capped' do
      d0 = described_class.backoff_seconds(0)
      d_high = described_class.backoff_seconds(20)

      # Jittered into [0.5, 1.0] of the capped delay.
      expect(d0).to be_between(0.5 * described_class::RECONNECT_BASE_SECONDS,
                               described_class::RECONNECT_BASE_SECONDS)
      expect(d_high).to be <= described_class::RECONNECT_MAX_SECONDS
      expect(d_high).to be >= 0.5 * described_class::RECONNECT_MAX_SECONDS
    end
  end
end
