require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    # Removes a developer from the roster (and their per-user settings). With no
    # expression the caller removes themselves; an @mention removes that user.
    module Deregister
      module_function

      def call(channel:, user:, expression:)
        target = expression.to_s.strip.empty? ? user : TargetParsing.extract_user(expression)
        UserRegister.remove(user: target, channel:)
      end
    end
  end
end
