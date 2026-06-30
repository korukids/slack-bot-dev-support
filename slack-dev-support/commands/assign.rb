require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    # Manually assigns the caller (`assign` / `assign me`) or a teammate
    # (`assign @user`) to dev-support for today. The current assignee is
    # displaced to the back of the rotation.
    module Assign
      module_function

      def call(channel:, user:, expression:)
        expr = expression.to_s.strip
        target = expr.casecmp('me').zero? ? user : TargetParsing.extract_target(expr, user).first
        result = UserRegister.assign_to_user(channel:, user: target)

        case result[:status]
        when :not_registered
          "<@#{target}> is not registered. Use `register` first."
        when :already_assigned
          "<@#{target}> is already on dev-support today."
        when :assigned
          "<@#{target}> is on dev-support"
        end
      end
    end
  end
end
