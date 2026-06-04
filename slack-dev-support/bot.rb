require_relative 'models/user_register'

module SlackDevSupport
  DEVELOPER_CHANNEL = 'GB66FUL2H'.freeze
  PRODUCT_DESIGN_CHANNEL = 'CG4VDUZ2L'.freeze

  class Bot < SlackRubyBot::Bot
    help do
      title 'dev-support bot'
      desc 'This bot assigns a dev to the dev-support channel every morning'

      command 'next' do
        desc 'This tells the bot to assign dev-support to the next person on the list'
        long_desc 'You can run this command at any time during the day, and it will move the current dev-support user to tomorrow and pick the next person in the rotation for today. You can run this until there are no more users to take over for today.'
      end

      command 'list' do
        desc 'This lists all the users in dev-support, annotated with work-days and away status'
      end

      command 'register' do
        desc 'Use this to register for dev-support'
        long_desc 'You can run this command with a target, for example "dev-support register @Frank"'
      end

      command 'deregister' do
        desc 'Use this to deregister for dev-support'
        long_desc 'You can run this command with a target, for example "dev-support deregister @Frank"'
      end

      command 'workdays' do
        desc 'View or set which days a user is eligible for dev-support'
        long_desc 'Examples: "workdays" (show yours), "workdays mon,tue,wed,thu", "workdays @Frank mon-thu", "workdays reset" (back to mon-fri)'
      end

      command 'assign' do
        desc 'Assign yourself or a teammate to dev-support for today'
        long_desc 'Usage: `assign`, `assign me`, or `assign @user`. The current assignee is displaced to the back of the rotation; other users keep their place in the cycle.'
      end

      command 'away' do
        desc 'Mark a user as away until a given date'
        long_desc 'Examples: "away until 2026-06-01", "away @Frank until 2026-06-01", "away clear". Away users are skipped by the scheduled assignment and `next`, and auto-return after the date.'
      end
    end
  end

  def self.assign_for(redis_channel:, announce_channel:, message_template:)
    # Daily rotation: tail becomes head (everyone shifts down one position).
    Redis.current.rpoplpush("#{redis_channel}_users", "#{redis_channel}_users")

    # Skip past anyone not working today.
    selected = UserRegister.advance_until_eligible(channel: redis_channel)

    if selected
      $slack_client.chat_postMessage(channel: announce_channel,
                                     text: format(message_template, user: "<@#{selected}>"))
    else
      $slack_client.chat_postMessage(channel: announce_channel, text: 'No-one is available today.')
    end
  end

  def self.assign
    assign_for(redis_channel: DEVELOPER_CHANNEL, announce_channel: $channel,
               message_template: '%<user>s is on dev support today!')
  end

  def self.assign_prod_design
    assign_for(redis_channel: PRODUCT_DESIGN_CHANNEL, announce_channel: $prod_design_channel,
               message_template: '%<user>s is your chair today!')
  end
end
