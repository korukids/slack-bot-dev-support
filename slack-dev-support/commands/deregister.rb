require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    # Removes a developer from the roster (and their per-user settings). With no
    # expression the caller removes themselves; an @mention removes that user.
    module Deregister
      module_function

      def call(channel:, user:, expression:)
        return UserRegister.remove(user:, channel:) if expression.to_s.strip.empty?

        target = TargetParsing.extract_user(expression, user)
        return TargetParsing.invalid_user_message(expression) if target.nil?

        UserRegister.remove(user: target, channel:)
      end
    end
  end
end
