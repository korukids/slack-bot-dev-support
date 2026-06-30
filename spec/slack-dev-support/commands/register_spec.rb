require 'spec_helper'

describe SlackDevSupport::Commands::Register do
  describe '.call' do
    context 'when the user is not registered' do
      it 'registers and returns a message' do
        expect(described_class.call(channel: 'channel', user: 'user', expression: ''))
          .to eq('Thanks for registering <@user>!')
      end
    end

    context 'when the user is registered' do
      it 'returns only a message' do
        Redis.current.lpush('channel_users', 'user')

        expect(described_class.call(channel: 'channel', user: 'user', expression: ''))
          .to eq("You've already registered <@user>!")
      end
    end

    context 'when multiple channels are using the bot' do
      it 'keeps a user register per channel' do
        expect(described_class.call(channel: 'channel1', user: 'user', expression: ''))
          .to eq('Thanks for registering <@user>!')
        expect(described_class.call(channel: 'channel2', user: 'user', expression: ''))
          .to eq('Thanks for registering <@user>!')
      end

      it 'still only allows a user to be registered once per channel' do
        Redis.current.lpush('channel1_users', 'user')
        expect(described_class.call(channel: 'channel1', user: 'user', expression: ''))
          .to eq("You've already registered <@user>!")
      end
    end

    context 'when a user registers a different user' do
      it 'registers and returns a message' do
        expect(described_class.call(channel: 'channel', user: 'user', expression: '<@user_2>'))
          .to eq('Thanks for registering <@user_2>!')
      end

      it 'registers the right id from a labelled mention <@id|name>' do
        expect(described_class.call(channel: 'channel', user: 'user', expression: '<@user_2|Finn>'))
          .to eq('Thanks for registering <@user_2>!')
      end
    end
  end
end
