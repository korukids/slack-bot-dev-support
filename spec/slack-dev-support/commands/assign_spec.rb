require 'spec_helper'

describe SlackDevSupport::Commands::Assign do
  describe '.call' do
    context 'self-assign (no expression)' do
      before do
        Redis.current.rpush('channel_users', 'user')
        Redis.current.rpush('channel_users', 'other')
      end

      it 'assigns caller and displaces previous' do
        expect(described_class.call(channel: 'channel', user: 'user', expression: ''))
          .to eq('<@user> is on dev-support')
      end
    end

    context "self-assign with 'me'" do
      before do
        Redis.current.rpush('channel_users', 'user')
        Redis.current.rpush('channel_users', 'other')
      end

      it 'assigns caller' do
        expect(described_class.call(channel: 'channel', user: 'user', expression: 'me'))
          .to eq('<@user> is on dev-support')
      end
    end

    context 'targeting another user' do
      before do
        Redis.current.rpush('channel_users', 'frank')
        Redis.current.rpush('channel_users', 'other')
      end

      it 'assigns the target' do
        expect(described_class.call(channel: 'channel', user: 'user', expression: '<@frank>'))
          .to eq('<@frank> is on dev-support')
      end
    end

    context 'already on duty' do
      before do
        Redis.current.rpush('channel_users', 'other')
        Redis.current.rpush('channel_users', 'user') # tail
      end

      it 'reports no-op' do
        expect(described_class.call(channel: 'channel', user: 'user', expression: ''))
          .to eq('<@user> is already on dev-support today.')
      end
    end

    context 'unregistered' do
      it 'rejects' do
        expect(described_class.call(channel: 'channel', user: 'user', expression: ''))
          .to eq('<@user> is not registered. Use `register` first.')
      end
    end
  end
end
