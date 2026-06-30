require 'spec_helper'

describe SlackDevSupport::Commands::List do
  describe '.call' do
    before do
      Redis.current.lpush('channel_users', 'user_1')
      Redis.current.lpush('channel_users', 'user_2')
      Redis.current.lpush('channel_users', 'user_3')
      Redis.current.lpush('channel_users', 'user_4')
      Redis.current.lpush('channel_users', 'user_5')
    end

    it 'returns the list' do
      expect(described_class.call(channel: 'channel'))
        .to eq('The current list is <@user_5>, <@user_4>, <@user_3>, <@user_2>, <@user_1>')
    end

    it 'returns the list specific to that channel' do
      Redis.current.lpush('channel2_users', 'Alice')
      Redis.current.lpush('channel2_users', 'Bob')

      expect(described_class.call(channel: 'channel2'))
        .to eq('The current list is <@Bob>, <@Alice>')
    end
  end
end
