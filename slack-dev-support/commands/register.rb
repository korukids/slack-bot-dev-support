require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    # Adds a developer to the roster. With no expression the caller registers
    # themselves; an @mention registers that user instead.
    module Register
      module_function

      def call(channel:, user:, expression:)
        return UserRegister.add(user:, channel:) if expression.to_s.strip.empty?

        target = TargetParsing.extract_user(expression, user)
        return TargetParsing.invalid_user_message(expression) if target.nil?

        UserRegister.add(user: target, channel:)
      end
    end
  end
end
