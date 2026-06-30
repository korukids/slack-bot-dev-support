module SlackDevSupport
  module Commands
    # Shared parser for command expressions that may begin with a Slack
    # @mention. Returns [target_user_id, remaining_expression].
    module TargetParsing
      # Slack renders a mention as "<@U123>" or, with a display label,
      # "<@U123|name>" — capture only the id, dropping the optional label.
      MENTION = /\A<@(\w+)(?:\|[^>]*)?>\s*(.*)\z/m

      def self.extract_target(expression, default_user)
        if (match = MENTION.match(expression))
          [match[1], match[2].strip]
        else
          [default_user, expression]
        end
      end

      # Resolve a single token to a bare user id, tolerating the labelled
      # mention form "<@U123|name>". Returns the raw token if it isn't a
      # mention (e.g. an already-bare id).
      def self.extract_user(token)
        stripped = token.to_s.strip
        match = MENTION.match(stripped)
        match ? match[1] : stripped
      end
    end
  end
end
