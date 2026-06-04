require_relative '../models/user_register'
require_relative 'target_parsing'

module SlackDevSupport
  module Commands
    class Assign < SlackRubyBot::Commands::Base
      help do
        command 'assign' do
          desc 'Assign yourself or a teammate to dev-support for today'
          long_desc <<~LONG
            Examples:
              assign            — assign yourself
              assign me         — assign yourself
              assign @Frank     — assign Frank
            The current assignee is displaced to the back of the rotation.
            Anyone sitting between the target and the old tail just shifts up
            in the cycle — only the displaced user loses their turn.
          LONG
        end
      end

      command 'assign' do |client, data, match|
        expression = match['expression'].to_s.strip
        target = expression.casecmp('me').zero? ? data.user : TargetParsing.extract_target(expression, data.user).first
        result = UserRegister.assign_to_user(channel: data.channel, user: target)

        text = case result[:status]
               when :not_registered
                 "<@#{target}> is not registered. Use `register` first."
               when :already_assigned
                 "<@#{target}> is already on dev-support today."
               when :assigned
                 "<@#{target}> is on dev-support"
               end

        client.say(channel: data.channel, text:)
      end

    end
  end
end
