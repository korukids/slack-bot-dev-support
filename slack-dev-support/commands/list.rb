require 'date'
require_relative '../models/user_register'

module SlackDevSupport
  module Commands
    # Lists everyone on the roster, annotated with non-default work-days and any
    # active away status.
    module List
      module_function

      def call(channel:, **_)
        members = UserRegister.list(channel:)

        formatted = members.map do |member|
          notes = []

          away = UserRegister.away_until(channel:, user: member)
          notes << "away until #{away}" if away && away >= Date.today

          work_days = UserRegister.work_days(channel:, user: member)
          notes << "works #{work_days.join('/')}" if work_days != UserRegister::DEFAULT_WORK_DAYS

          notes.empty? ? "<@#{member}>" : "<@#{member}> (#{notes.join('; ')})"
        end

        "The current list is #{formatted.join(', ')}"
      end
    end
  end
end
