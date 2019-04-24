module SlackDevSupport
  module Commands
    class Help < SlackRubyBot::Commands::Base
      command 'help' do |client, data, _match|
        client.say(channel: data.channel, text: "The current commands are, list, rotate, register, unregister, yes, no")
      end
    end
  end
end

