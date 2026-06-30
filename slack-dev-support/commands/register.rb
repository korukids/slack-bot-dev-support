require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    # Adds a developer to the roster. With no expression the caller registers
    # themselves; an @mention registers that user instead.
    module Register
      module_function

      def call(channel:, user:, expression:)
        target = expression.to_s.strip.empty? ? user : TargetParsing.extract_user(expression)
        UserRegister.add(user: target, channel:)
      end
    end
  end
end
