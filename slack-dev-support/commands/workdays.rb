require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    class Workdays < SlackRubyBot::Commands::Base
      VALID_DAYS = UserRegister::DAY_KEYS

      help do
        command 'workdays' do
          desc "View or set a user's eligible days for dev-support"
          long_desc <<~LONG
            Examples:
              workdays                       — show your own work-days
              workdays mon,tue,wed,thu       — set yours to Mon-Thu
              workdays mon-thu               — same, range form
              workdays @Frank mon,wed,fri    — set someone else's
              workdays reset                 — back to mon-fri (default)
              workdays @Frank reset
          LONG
        end
      end

      command 'workdays' do |client, data, match|
        expression = match['expression'].to_s.strip

        target, rest = TargetParsing.extract_target(expression, data.user)

        text =
          if rest.empty?
            current = UserRegister.work_days(channel: data.channel, user: target)
            "<@#{target}> works: #{current.join(', ')}"
          elsif rest.downcase == 'reset'
            UserRegister.reset_work_days(channel: data.channel, user: target)
            "<@#{target}>'s work-days reset to default (mon-fri)."
          else
            days = Workdays.parse_days(rest)
            if days.nil?
              "Couldn't parse `#{rest}`. Try a comma list (`mon,tue,wed`) or a range (`mon-thu`)."
            elsif days.empty?
              "You must specify at least one work-day. Use `deregister` to remove yourself entirely."
            else
              UserRegister.set_work_days(channel: data.channel, user: target, days:)
              "<@#{target}>'s work-days set to: #{days.join(', ')}"
            end
          end

        client.say(channel: data.channel, text:)
      end

      def self.parse_days(input)
        tokens = input.downcase.split(/[\s,]+/).reject(&:empty?)
        days = []
        tokens.each do |tok|
          expanded = expand_range(tok)
          return nil if expanded.nil?

          days.concat(expanded)
        end
        days.uniq
      end

      def self.expand_range(token)
        if token.include?('-')
          from, to = token.split('-', 2)
          start_idx = VALID_DAYS.index(from)
          end_idx = VALID_DAYS.index(to)
          return nil if start_idx.nil? || end_idx.nil? || end_idx < start_idx

          VALID_DAYS[start_idx..end_idx]
        else
          return nil unless VALID_DAYS.include?(token)

          [token]
        end
      end
    end
  end
end
