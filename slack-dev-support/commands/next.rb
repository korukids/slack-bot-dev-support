require_relative '../models/user_register'

module SlackDevSupport
  module Commands
    # Skips today's assignee and picks the next eligible developer in the
    # rotation. Takes no arguments beyond the channel.
    module Next
      module_function

      def call(channel:, **_)
        selected = UserRegister.skip(channel:)
        selected ? "<@#{selected}> is on dev-support" : 'No-one is available for dev-support today.'
      end
    end
  end
end
