require 'json'
require 'logger'
require 'eventmachine'
require 'faye/websocket'
require 'slack-ruby-client'

require_relative 'listeners/support_listener'
require_relative 'dispatcher'

module SlackDevSupport
  # Socket Mode runtime — the replacement for the old RTM connection.
  #
  # Slack's RTM API is gone for modern apps; Socket Mode is the documented
  # successor. We ask the Web API for a temporary WebSocket URL
  # (apps.connections.open, authed with the *app-level* xapp- token), open it,
  # and translate the events it streams into the same SupportListener /
  # Dispatcher calls the RTM hooks used to make.
  #
  # Envelopes that carry an `envelope_id` MUST be acknowledged within 3 seconds
  # or Slack retries them, so we ack first, then process.
  module SocketMode
    # Reconnect backoff: double from BASE up to MAX seconds, with jitter, so a
    # persistent failure (revoked token, Slack outage) doesn't become a tight
    # one-second retry storm against the rate-limited apps.connections.open.
    RECONNECT_BASE_SECONDS = 1
    RECONNECT_MAX_SECONDS = 30

    module_function

    # Logs to stdout so it shows up under `rackup`/foreman alongside the web
    # process. Set LOG_LEVEL=debug to see raw envelopes.
    def logger
      @logger ||= Logger.new($stdout).tap do |l|
        l.level = ENV.fetch('LOG_LEVEL', 'info').upcase
        l.progname = 'socket_mode'
      end
    end

    # Blocks, running the EventMachine reactor. Reconnects on socket close.
    def run
      bot_id = bot_user_id
      raise 'Could not resolve the bot user id from auth.test; check SLACK_API_TOKEN' if bot_id.nil?

      logger.info("starting; bot user id #{bot_id}, support channel #{$channel}")
      EM.run do
        connect(bot_id)
      end
    end

    def connect(bot_id, attempt: 0)
      logger.info("opening Socket Mode connection (attempt #{attempt + 1})")
      url = open_connection_url
      ws = Faye::WebSocket::Client.new(url)
      opened = false

      # A clean open resets the backoff, so the next outage starts from BASE
      # rather than wherever the previous reconnect sequence left off.
      ws.on :open do |_event|
        opened = true
        logger.info('Socket Mode connection open; waiting for events')
      end

      ws.on :message do |event|
        handle_envelope(ws, JSON.parse(event.data), bot_id)
      rescue StandardError => e
        logger.error("message error: #{e}")
      end

      ws.on :error do |event|
        # An :error doesn't always precede a clean :close, so reconnect here
        # too rather than risk sitting on a dead socket forever.
        logger.error("socket error: #{event.message}")
        reconnect(bot_id, opened ? 0 : attempt)
      end

      ws.on :close do |event|
        logger.warn("socket closed (#{event.code} #{event.reason}); reconnecting")
        reconnect(bot_id, opened ? 0 : attempt)
      end
    rescue StandardError => e
      # open_connection_url / client construction can raise (network blip, 429,
      # missing url). Without this the exception escapes the reactor and, with
      # abort_on_exception, kills the bot thread permanently.
      logger.error("connect failed: #{e}")
      reconnect(bot_id, attempt)
    end

    # Schedule the next connect on the reactor with exponential backoff + jitter.
    # Guarded so a burst of :error + :close on the same socket only schedules one.
    def reconnect(bot_id, attempt)
      return if @reconnecting

      @reconnecting = true
      delay = backoff_seconds(attempt)
      EM.add_timer(delay) do
        @reconnecting = false
        connect(bot_id, attempt: attempt + 1)
      end
    end

    def backoff_seconds(attempt)
      capped = [RECONNECT_BASE_SECONDS * (2**attempt), RECONNECT_MAX_SECONDS].min
      capped * (0.5 + (rand * 0.5)) # jitter in [0.5, 1.0] of the capped delay
    end

    # One Socket Mode envelope. Types we see: "hello" (no ack), "disconnect"
    # (Slack is rotating the socket — let it close and reconnect), and
    # "events_api" (the actual event payload, must be acked).
    def handle_envelope(ws, envelope, bot_id)
      logger.debug { "envelope: #{envelope.inspect}" }
      ack(ws, envelope['envelope_id']) if envelope['envelope_id']

      case envelope['type']
      when 'events_api'
        event = envelope.dig('payload', 'event')
        if event
          logger.info("event received: #{event['type']} in #{event['channel'] || event.dig('item', 'channel')}")
          dispatch_event(event, bot_id)
        end
      when 'hello'
        logger.info("hello (#{envelope['num_connections']} connection(s) for this app)")
      when 'disconnect'
        logger.info("disconnect requested (#{envelope['reason']}); awaiting socket close")
      end
    end

    def ack(ws, envelope_id)
      ws.send(JSON.generate(envelope_id:))
    end

    # Translate a Slack Events API event into our listener/dispatcher calls.
    # Mirrors the three RTM hooks that used to live in bot.rb, plus command
    # dispatch (which RTM handled inside slack-ruby-bot).
    def dispatch_event(event, bot_id)
      case event['type']
      when 'message'
        handle_message_event(event, bot_id)
      when 'reaction_added', 'reaction_removed'
        handle_reaction_event(event)
      end
    end

    def handle_message_event(event, bot_id)
      # Passive request tracking — every top-level message in the channel.
      SupportListener.handle_message(
        channel: event['channel'],
        user: event['user'],
        text: event['text'],
        ts: event['ts'],
        thread_ts: event['thread_ts'],
        subtype: event['subtype'],
        bot_id: event['bot_id']
      )

      skip = command_skip_reason(event, bot_id)
      return logger.debug { "skip dispatch: #{skip}" } if skip

      reply = Dispatcher.dispatch(
        text: event['text'],
        channel: event['channel'],
        user: event['user'],
        bot_id:
      )
      if reply
        logger.info("dispatched command from #{event['user']}; replying")
        post(channel: event['channel'], text: reply)
      else
        logger.debug { "no command matched for text: #{event['text'].inspect}" }
      end
    rescue StandardError => e
      logger.error("message handler error: #{e}")
    end

    # Why this message should NOT trigger command dispatch, or nil if it should.
    # Commands run only for top-level, human, non-bot messages in the support
    # channel — the listener above is already channel-gated, but the command
    # path must be too, or the bot would mutate rosters keyed off any other
    # channel it's a member of.
    def command_skip_reason(event, bot_id)
      if event['channel'] != $channel
        "channel #{event['channel']} != support channel #{$channel}"
      elsif !event['thread_ts'].nil?
        'thread reply'
      elsif !(event['subtype'].nil? && event['bot_id'].nil?)
        "subtype=#{event['subtype']} bot_id=#{event['bot_id']}"
      elsif event['user'].nil? || event['user'] == bot_id
        'from bot or no user'
      end
    end

    def handle_reaction_event(event)
      logger.info(":#{event['reaction']}: #{event['type']} on #{event.dig('item', 'ts')}")
      SupportListener.handle_reaction(
        action: event['type'] == 'reaction_added' ? :added : :removed,
        name: event['reaction'],
        item_ts: event.dig('item', 'ts'),
        item_channel: event.dig('item', 'channel')
      )
    rescue StandardError => e
      logger.error("reaction handler error: #{e}")
    end

    # --- Slack Web API helpers ---

    # apps.connections.open needs the app-level token (xapp-), which is distinct
    # from the bot token ($slack_client uses for posting).
    def app_client
      @app_client ||= Slack::Web::Client.new(token: ENV.fetch('SLACK_APP_TOKEN'))
    end

    def open_connection_url
      response = app_client.apps_connections_open
      url = response['url']
      raise "apps.connections.open returned no url (#{response['error'] || 'unknown error'})" if url.nil?

      logger.debug('got Socket Mode wss url from apps.connections.open')
      url
    end

    # chat.postMessage is a blocking HTTP round-trip. Run it on EM's thread pool
    # so a slow post (or a 429) doesn't stall the single-threaded reactor and
    # delay acks for queued envelopes — which would cause Slack to redeliver
    # them and re-run commands.
    def post(channel:, text:)
      EM.defer do
        $slack_client.chat_postMessage(channel:, text:)
        logger.info("posted to #{channel}")
      rescue StandardError => e
        logger.error("post error: #{e}")
      end
    end

    # The bot's own user id — used to detect mentions and to ignore the bot's
    # own messages. Replaces SlackRubyBot.config.user_id. auth.test runs against
    # the bot token.
    def bot_user_id
      $bot_user_id ||= $slack_client.auth_test['user_id']
    end
  end
end
