module SlackDevSupport
  module Commands
    class SetTime < SlackRubyBot::Commands::Base
      command 'set time' do |client, data, match|
        time = match[:expression]

        if /((1[0-2]|0?[1-9]):([0-5][0-9]) ?([AaPp][Mm]))/.match?(time)
          Redis.current.set('time', time)
          client.say(channel: data.channel, text: "Time set to #{time}")
        else
          client.say(channel: data.channel, text: "I didn't understand that format, try using something like 09:00am")
        end
      end
    end
  end
end 