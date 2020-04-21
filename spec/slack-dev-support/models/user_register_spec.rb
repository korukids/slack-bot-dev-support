require 'spec_helper'
require_relative '../../../slack-dev-support/models/user_register.rb'

describe UserRegister do
  it 'registers a user on a channels list' do
    user = "user_1"
    channel_name = "channel_1"
    described_class.add(user: user, channel: channel_name)

    expect(described_class.list(channel: channel_name)).to include(user)
  end

  it 'returns "thanks for registering" if the user is not on the register' do
    user = "user_1"
    channel_name = "channel_1"
    response = described_class.add(user: user, channel: channel_name)

    expect(response).to eq("Thanks for registering <@user_1>!")
  end

  it 'keeps independent register for each channel' do
    user = "user_1"
    channel_1_name = "channel_1"
    channel_2_name = "channel_2"
    described_class.add(user: user, channel: channel_1_name)

    expect(described_class.list(channel: channel_2_name)).not_to include(user)
  end

  it 'returns "you have already registered" if the user already exists on the register' do
    user = "user_1"
    channel_name = "channel_1"
    described_class.add(user: user, channel: channel_name)

    expect(described_class.add(user: user, channel: channel_name)).to eq("You've already registered <@user_1>!")
  end
end
