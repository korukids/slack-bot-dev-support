require_relative '../models/support_request'
require_relative '../models/user_register'

module SlackDevSupport
  # Translates Slack RTM events in the support channel into SupportRequest
  # lifecycle transitions. Methods take plain fields (not RTM structs) so they
  # are unit-testable without a live client; the bot's `on(...)` hooks are thin
  # wrappers that forward event data here.
  module SupportListener
    # Emojis that close a request. Both check and cross simply mean "closed".
    CLOSE_REACTIONS = %w[white_check_mark heavy_check_mark ballot_box_with_check x].freeze
    INVESTIGATE_REACTION = 'eyes'.freeze

    module_function

    def handle_message(channel:, user:, text:, ts:, thread_ts:, subtype:, bot_id:)
      return unless channel == $channel

      if thread_ts.nil?
        return unless subtype.nil? && bot_id.nil? && user && user != bot_user_id

        SupportRequest.create_request(ts:, user:, text:, channel:)
      else
        handle_thread_reply(parent_ts: thread_ts, user:, reply_ts: ts)
      end
    end

    def handle_thread_reply(parent_ts:, user:, reply_ts:)
      return if user.nil? || user == bot_user_id

      request = SupportRequest.get(ts: parent_ts)
      return if request.nil?
      return if user == request['user'] # the original poster replying isn't an ack
      return unless known_developer?(user)

      SupportRequest.mark_acknowledged(ts: parent_ts, by: user, at: reply_ts)
    end

    def handle_reaction(action:, name:, item_ts:, item_channel:)
      return unless item_channel == $channel

      added = action == :added

      if name == INVESTIGATE_REACTION
        if added
          SupportRequest.mark_investigating(ts: item_ts, at: now_epoch)
        else
          SupportRequest.clear_investigating(ts: item_ts)
        end
      elsif CLOSE_REACTIONS.include?(name)
        if added
          SupportRequest.mark_closed(ts: item_ts, at: now_epoch)
        else
          SupportRequest.reopen(ts: item_ts)
        end
      end
    end

    def known_developer?(user)
      UserRegister.list_active(channel: $channel).include?(user)
    end

    def bot_user_id
      SlackRubyBot.config.user_id
    end

    def now_epoch
      Time.now.to_i
    end
  end
end
