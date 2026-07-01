require 'spec_helper'

describe SlackDevSupport::Commands::Deregister do
  describe '.call' do
    context 'when the user is provided' do
      before { Redis.current.lpush('users_users', 'user') }

      it 'removes the user' do
        expect(described_class.call(channel: 'users', user: 'caller', expression: '<@user>'))
          .to eq('<@user> has been deregistered')
      end
    end

    context 'when the user is deregistering themselves' do
      before { Redis.current.lpush('users_users', 'user') }

      it 'deregisters them and returns a message' do
        expect(described_class.call(channel: 'users', user: 'user', expression: ''))
          .to eq('<@user> has been deregistered')
      end
    end

    context 'when given a labelled mention <@id|name>' do
      before { Redis.current.lpush('users_users', 'user') }

      it 'removes the right id' do
        expect(described_class.call(channel: 'users', user: 'caller', expression: '<@user|Jake>'))
          .to eq('<@user> has been deregistered')
      end
    end
  end
end
