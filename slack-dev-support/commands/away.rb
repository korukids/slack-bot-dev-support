require 'date'
require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    class Away < SlackRubyBot::Commands::Base
      help do
        command 'away' do
          desc 'Mark a user as away until a given date'
          long_desc <<~LONG
            Examples:
              away until 2026-06-01            — you're away through 2026-06-01 (inclusive)
              away until next friday           — anything Ruby's Date.parse accepts
              away @Frank until 2026-06-01     — set someone else
              away clear / away cancel         — clear the away flag
              away                             — show your current status
            The bot echoes back the resolved date so you can spot misreadings.
          LONG
        end
      end

      command 'away' do |client, data, match|
        expression = match['expression'].to_s.strip
        target, rest = TargetParsing.extract_target(expression, data.user)

        text =
          if rest.empty?
            current = UserRegister.away_until(channel: data.channel, user: target)
            current ? "<@#{target}> is away until #{current}." : "<@#{target}> is not marked away."
          elsif %w[clear cancel].include?(rest.downcase)
            UserRegister.clear_away(channel: data.channel, user: target)
            "<@#{target}> is no longer marked away."
          elsif (date = Away.parse_until(rest))
            if date < Date.today
              "That date (#{date}) is in the past."
            else
              UserRegister.set_away_until(channel: data.channel, user: target, date:)
              "<@#{target}> marked away until #{date} (#{date.strftime('%A %-d %B %Y')})."
            end
          else
            "Couldn't parse `#{rest}`. Try `until 2026-06-01` or `clear`."
          end

        client.say(channel: data.channel, text:)
      end

      def self.parse_until(input)
        stripped = input.sub(/\Auntil\s+/i, '').strip
        Date.parse(stripped)
      rescue ArgumentError
        nil
      end
    end
  end
end
