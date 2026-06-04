module SlackDevSupport
  module Commands
    # Shared parser for command expressions that may begin with a Slack
    # @mention. Returns [target_user_id, remaining_expression].
    module TargetParsing
      MENTION = /\A<@([^>]+)>\s*(.*)\z/

      def self.extract_target(expression, default_user)
        if (match = MENTION.match(expression))
          [match[1], match[2].strip]
        else
          [default_user, expression]
        end
      end
    end
  end
end
