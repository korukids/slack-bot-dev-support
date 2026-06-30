module SlackDevSupport
  module Commands
    # Shared parser for command expressions that may begin with a user
    # reference. A user reference is either a Slack @mention ("<@U123>" or the
    # labelled "<@U123|name>") or the keyword "me" (the caller). A bare word
    # like "frank" is NOT a valid reference — Slack only ever sends real users
    # as <@…> mentions, so anything else is a typo or a non-existent user.
    module TargetParsing
      # Captures the user id from a mention, dropping any "|label".
      MENTION = /\A<@(\w+)(?:\|[^>]*)?>\s*(.*)\z/m
      SELF_KEYWORD = 'me'.freeze

      # Split an expression into [target_user_id, remaining_expression].
      # A leading @mention or "me" is consumed as the target; otherwise there is
      # no explicit target and the whole expression belongs to the caller (e.g.
      # "workdays mon-thu" sets the caller's own days).
      def self.extract_target(expression, default_user)
        stripped = expression.to_s.strip

        if (match = MENTION.match(stripped))
          [match[1], match[2].strip]
        elsif (rest = self_keyword_rest(stripped))
          [default_user, rest]
        else
          [default_user, stripped]
        end
      end

      # Resolve a token that is expected to be a whole user reference to a bare
      # user id. "me" -> the caller; "<@U123>"/"<@U123|name>" -> "U123".
      # Returns nil when the token isn't a valid reference (e.g. "frank"), so
      # callers can reject it instead of storing a bogus id.
      def self.extract_user(token, caller_user)
        stripped = token.to_s.strip
        return caller_user if stripped.casecmp(SELF_KEYWORD).zero?

        match = MENTION.match(stripped)
        match && match[2].strip.empty? ? match[1] : nil
      end

      # If the expression starts with the "me" keyword, return the remaining
      # text (so "away me until …" works); otherwise nil.
      def self.self_keyword_rest(expression)
        return unless (md = /\A#{SELF_KEYWORD}\b\s*(.*)\z/mi.match(expression))

        md[1].strip
      end

      # Feedback when a user reference can't be resolved to a real user.
      def self.invalid_user_message(input)
        "Couldn't resolve `#{input.to_s.strip}` to a user. Mention someone " \
          '(`@name`), use `me`, or run the command with no name for yourself.'
      end
    end
  end
end
