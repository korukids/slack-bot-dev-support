require 'logger'
require_relative '../models/support_request'
require_relative '../models/user_register'

module SlackDevSupport
  # Translates Slack RTM events in the support channel into SupportRequest
  # lifecycle transitions. Methods take plain fields (not RTM structs) so they
  # are unit-testable without a live client; the bot's `on(...)` hooks are thin
  # wrappers that forward event data here.
  module SupportListener
    # Emojis that close a request. Check, thumbs up (:+1:) and cross all simply mean "closed".
    CLOSE_REACTIONS = %w[white_check_mark heavy_check_mark ballot_box_with_check +1 x].freeze
    INVESTIGATE_REACTION = 'eyes'.freeze

    # Message subtypes we still treat as a new support request:
    #   nil          - a plain message (this also covers a message that just
    #                  carries an attachment in a `files` array with no subtype).
    #   file_share   - a message whose attachment makes Slack tag it `file_share`
    #                  instead of leaving the subtype nil. Same human action as
    #                  above (raising a request with a screenshot/log); we track
    #                  it either way rather than depend on which form Slack sends.
    # Every other subtype is a system event (joins, topic changes, pins…), a bot
    # post (`bot_message`), or an edit (`message_changed`/`message_deleted`) —
    # none of which is a new request.
    TRACKABLE_SUBTYPES = [nil, 'file_share'].freeze

    module_function

    def handle_message(channel:, user:, text:, ts:, thread_ts:, subtype:, bot_id:)
      return unless channel == $channel

      if thread_ts.nil?
        unless TRACKABLE_SUBTYPES.include?(subtype) && bot_id.nil? && from_human?(user)
          return log.debug { "not tracking ts=#{ts}: subtype=#{subtype.inspect} bot_id=#{bot_id.inspect} user=#{user.inspect}" }
        end
        # Messages addressed to the bot are commands, not support requests.
        return log.debug { "not tracking ts=#{ts}: addressed to the bot" } if mentions_bot?(text)

        log.info("tracking new request ts=#{ts} from #{user}: #{text.to_s.strip[0, 80].inspect}")
        SupportRequest.create_request(ts:, user:, text:, channel:)
      else
        handle_thread_reply(parent_ts: thread_ts, user:, reply_ts: ts)
      end
    end

    # A real person, and not the bot itself. Guard against bot_user_id being
    # nil (a failed auth.test) so a nil never accidentally matches a nil user.
    def from_human?(user)
      !user.nil? && (bot_user_id.nil? || user != bot_user_id)
    end

    # True when the text @mentions the bot (e.g. "<@U123> register"). Slack may
    # render the mention with a label ("<@U123|name>").
    def mentions_bot?(text)
      return false if bot_user_id.nil?

      text.to_s.match?(/<@#{Regexp.escape(bot_user_id)}(?:\|[^>]*)?>/)
    end

    def handle_thread_reply(parent_ts:, user:, reply_ts:)
      return if user.nil? || user == bot_user_id

      request = SupportRequest.get(ts: parent_ts)
      return log.debug { "thread reply on untracked parent ts=#{parent_ts}; ignoring" } if request.nil?
      return if user == request['user'] # the original poster replying isn't an ack
      return unless known_developer?(user)

      log.info("acknowledging request ts=#{parent_ts} by #{user}")
      SupportRequest.mark_acknowledged(ts: parent_ts, by: user, at: reply_ts)
    end

    # A message in the channel was deleted. A no-op for anything we weren't
    # tracking (thread replies, bot posts, commands).
    def handle_deletion(channel:, ts:)
      return unless channel == $channel
      return if ts.nil?
      return unless SupportRequest.exists?(ts)

      log.info("request ts=#{ts} was deleted; no longer tracking it")
      SupportRequest.delete(ts:)
    end

    # Slack reactions are per user, so an added or removed reaction says little
    # on its own: removing one close emoji doesn't mean none are left (a
    # different close emoji, or someone else's). So for any close or :eyes:
    # reaction we ask Slack what's on the message now and set the state to
    # match. That makes a Slack API call, so callers should run this off the
    # reactor, one event at a time and in arrival order, so the last check made
    # always sees the latest reactions.
    def handle_reaction(action:, name:, item_ts:, item_channel:)
      return unless item_channel == $channel

      name = base_emoji(name)
      return log.debug { "ignoring reaction :#{name}: on ts=#{item_ts}" } unless tracked_reaction?(name)
      return unless SupportRequest.exists?(item_ts)

      present = reaction_present?(name:, action:, item_ts:, item_channel:)
      return if present.nil?

      if name == INVESTIGATE_REACTION
        sync_investigating(item_ts:, present:, cause: ":#{name}: #{action}")
      else
        sync_closed(item_ts:, present:, cause: ":#{name}: #{action}")
      end
    end

    def tracked_reaction?(name)
      name == INVESTIGATE_REACTION || CLOSE_REACTIONS.include?(name)
    end

    # Whether the message currently carries a reaction of the same kind as
    # `name` (any :eyes:, or any close emoji), by anyone. If Slack can't be
    # asked, trust an addition (it's a fact on its own) but ignore a removal
    # (nil: leave the state alone) rather than wrongly reopen.
    def reaction_present?(name:, action:, item_ts:, item_channel:)
      kinds = name == INVESTIGATE_REACTION ? [INVESTIGATE_REACTION] : CLOSE_REACTIONS
      current_reactions(channel: item_channel, ts: item_ts).any? { |r| kinds.include?(r) }
    rescue StandardError => e
      log.error("reactions.get failed for ts=#{item_ts} (:#{name}: #{action}): #{e}")
      action == :added ? true : nil
    end

    def sync_investigating(item_ts:, present:, cause:)
      log.info("#{cause} on request ts=#{item_ts} -> #{present ? 'investigating' : 'not investigating'}")
      if present
        SupportRequest.mark_investigating(ts: item_ts, at: now_epoch)
      else
        SupportRequest.clear_investigating(ts: item_ts)
      end
    end

    def sync_closed(item_ts:, present:, cause:)
      log.info("#{cause} on request ts=#{item_ts} -> #{present ? 'closed' : 'open'}")
      if present
        SupportRequest.mark_closed(ts: item_ts, at: now_epoch)
      else
        SupportRequest.reopen(ts: item_ts)
      end
    end

    # Emoji names currently on the message, skin tones folded away. `full`
    # stops Slack truncating the list on a heavily-reacted message.
    def current_reactions(channel:, ts:)
      response = $slack_client.reactions_get(channel:, timestamp: ts, full: true)
      (response.dig('message', 'reactions') || []).map { |r| base_emoji(r['name']) }
    end

    # Slack names a skin-toned reaction "+1::skin-tone-3"; it is still a :+1:.
    def base_emoji(name)
      name.to_s.sub(/::skin-tone-\d+\z/, '')
    end

    def known_developer?(user)
      UserRegister.list_active(channel: $channel).include?(user)
    end

    def bot_user_id
      $bot_user_id
    end

    # Share the Socket Mode stdout logger when the runtime is loaded; fall back
    # to a null logger so the listener stays usable from specs / Rake tasks
    # that never start the reactor.
    def log
      if defined?(SocketMode) && SocketMode.respond_to?(:logger)
        SocketMode.logger
      else
        @null_logger ||= Logger.new(File::NULL)
      end
    end

    def now_epoch
      Time.now.to_i
    end
  end
end
