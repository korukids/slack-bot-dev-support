require 'date'
require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    # Marks a developer away through a given date (inclusive), clears the flag,
    # or shows current status. Away users are skipped until the date passes.
    module Away
      module_function

      def call(channel:, user:, expression:)
        target, rest = TargetParsing.extract_target(expression.to_s.strip, user)

        if rest.empty?
          current = UserRegister.away_until(channel:, user: target)
          current ? "<@#{target}> is away until #{current}." : "<@#{target}> is not marked away."
        elsif %w[clear cancel].include?(rest.downcase)
          UserRegister.clear_away(channel:, user: target)
          "<@#{target}> is no longer marked away."
        elsif (date = parse_until(rest))
          set_until(channel:, target:, date:)
        else
          "Couldn't parse `#{rest}`. Try `until 2026-06-01` or `clear`."
        end
      end

      def set_until(channel:, target:, date:)
        if date < Date.today
          "That date (#{date}) is in the past."
        else
          UserRegister.set_away_until(channel:, user: target, date:)
          "<@#{target}> marked away until #{date} (#{date.strftime('%A %-d %B %Y')})."
        end
      end

      def parse_until(input)
        stripped = input.sub(/\Auntil\s+/i, '').strip
        Date.parse(stripped)
      rescue ArgumentError
        nil
      end
    end
  end
end
