require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    # Views or sets which days a developer is eligible for dev-support. Accepts
    # comma lists (`mon,tue,wed`), ranges (`mon-thu`), or `reset`.
    module Workdays
      VALID_DAYS = UserRegister::DAY_KEYS

      module_function

      def call(channel:, user:, expression:)
        target, rest = TargetParsing.extract_target(expression.to_s.strip, user)

        if rest.empty?
          current = UserRegister.work_days(channel:, user: target)
          "<@#{target}> works: #{current.join(', ')}"
        elsif rest.downcase == 'reset'
          UserRegister.reset_work_days(channel:, user: target)
          "<@#{target}>'s work-days reset to default (mon-fri)."
        else
          set_days(channel:, target:, rest:)
        end
      end

      def set_days(channel:, target:, rest:)
        days = parse_days(rest)
        if days.nil?
          "Couldn't parse `#{rest}`. Try a comma list (`mon,tue,wed`) or a range (`mon-thu`)."
        elsif days.empty?
          'You must specify at least one work-day. Use `deregister` to remove yourself entirely.'
        else
          UserRegister.set_work_days(channel:, user: target, days:)
          "<@#{target}>'s work-days set to: #{days.join(', ')}"
        end
      end

      def parse_days(input)
        tokens = input.downcase.split(/[\s,]+/).reject(&:empty?)
        days = []
        tokens.each do |tok|
          expanded = expand_range(tok)
          return nil if expanded.nil?

          days.concat(expanded)
        end
        days.uniq
      end

      def expand_range(token)
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
