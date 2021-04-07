require 'spec_helper'

describe SlackDevSupport::Bot do
  def app
    SlackDevSupport::Bot.instance
  end

  subject { app }

  it_behaves_like 'a slack ruby bot'
end
