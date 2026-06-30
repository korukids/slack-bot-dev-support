require_relative 'commands/register'
require_relative 'commands/deregister'
require_relative 'commands/next'
require_relative 'commands/list'
require_relative 'commands/assign'
require_relative 'commands/workdays'
require_relative 'commands/away'

module SlackDevSupport
  # Routes an @mention message to a command module and returns the reply text.
  #
  # Replaces slack-ruby-bot's command DSL: messages arrive as raw text like
  # "<@UBOT> register <@UFRANK>". We strip the leading bot mention, take the
  # first token as the command, and pass the remainder to the command's `.call`
  # as the expression. Returns nil when the message isn't addressed to the bot,
  # so the transport layer can stay silent.
  module Dispatcher
    # Maps a command word to its command module. Each module responds to
    # `.call(channel:, user:, expression:)` and returns the reply String.
    COMMANDS = {
      'register' => Commands::Register,
      'deregister' => Commands::Deregister,
      'next' => Commands::Next,
      'list' => Commands::List,
      'assign' => Commands::Assign,
      'workdays' => Commands::Workdays,
      'away' => Commands::Away
    }.freeze

    module_function

    # text:    raw message text from Slack
    # channel: channel id the message was posted in
    # user:    the user id who sent it
    # bot_id:  the bot's own user id, used to detect/strip the leading mention
    #
    # Returns the reply String, or nil if the message isn't a command for us.
    def dispatch(text:, channel:, user:, bot_id:)
      body = strip_leading_mention(text.to_s, bot_id)
      return nil if body.nil? # not addressed to the bot

      word, expression = body.split(/\s+/, 2)
      word = word.to_s.downcase
      expression = expression.to_s.strip

      return help_text if word == 'help' || word.empty?

      command = COMMANDS[word]
      return unknown_command(word) if command.nil?

      command.call(channel:, user:, expression:)
    end

    # Returns the message with a leading "<@BOT>" mention removed, or nil if the
    # text doesn't start with a mention of this bot. Slack mentions can carry a
    # label: "<@U123|name>".
    def strip_leading_mention(text, bot_id)
      stripped = text.strip
      mention = /\A<@#{Regexp.escape(bot_id.to_s)}(?:\|[^>]*)?>\s*/
      return nil unless bot_id && stripped.match?(mention)

      stripped.sub(mention, '').strip
    end

    def unknown_command(word)
      "Sorry, I don't know the command `#{word}`. Try `help`."
    end

    def help_text
      <<~HELP.strip
        *dev-support bot* — assigns a dev to the support channel each morning. Mention me with one of:

        • `list` — show everyone on the roster, with work-days and away status
        • `next` — skip today's assignee and pick the next eligible person
        • `register [@user]` — add yourself (or someone) to the roster
        • `deregister [@user]` — remove yourself (or someone) from the roster
        • `assign [me|@user]` — assign yourself or a teammate to today; the current assignee is displaced to the back
        • `workdays [@user] [days|reset]` — view or set eligible days, e.g. `workdays mon-thu` or `workdays reset`
        • `away [@user] until YYYY-MM-DD | clear` — mark someone away (skipped until the date), or clear it
        • `help` — show this message
      HELP
    end
  end
end
