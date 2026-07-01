require 'date'
require_relative 'models/user_register'
require_relative 'models/support_request'
require_relative 'listeners/support_listener'

# Scheduled-post behaviour, invoked by the Rake tasks (assign / support_nudge /
# support_summary) as SlackDevSupport.assign etc. Event handling and command
# dispatch now live in SocketMode + Dispatcher; this module only owns the
# messages the external scheduler triggers. Everything here posts via the Web
# API ($slack_client).
module SlackDevSupport
  # Daily assignment. Rotates the roster (keyed off the channel), skips anyone
  # not working today, and posts a single message that both names today's
  # on-support dev and sets expectations for the team.
  def self.assign
    # Daily rotation: tail becomes head (everyone shifts down one position).
    Redis.current.rpoplpush("#{$channel}_users", "#{$channel}_users")

    # Skip past anyone not working today.
    selected = UserRegister.advance_until_eligible(channel: $channel)

    text = [assignment_message(selected), carryover_note].compact.join("\n\n")
    post(text)
  end

  # Appended to the daily message when requests are still open from previous
  # days, so nothing silently rolls over. nil when there's no carryover.
  def self.carryover_note
    carried = SupportRequest.open_requests.reject { |r| created_today?(r) }
    return if carried.empty?

    lines = carried.map { |r| format_request_line(r) }
    "Still open from previous days:\n#{lines.join("\n")}"
  end

  # The morning post. Order: who's on support, how to raise a request, when
  # we'll look, and how to escalate.
  def self.assignment_message(user)
    unless user
      return 'No-one is on dev support today. Please post requests here and ' \
             'ping the team directly if something is urgent.'
    end

    mention = "<@#{user}>"
    ":wave: #{mention} is on dev support today. " \
      "Post your requests here and we'll check in through the day. " \
      "If something is urgent, ping #{mention} directly. "
  end

  # Today's on-support dev — the tail of the rotation (same convention the daily
  # assignment uses). Returns a Slack mention, or a neutral phrase if empty.
  def self.current_support_dev_mention
    user = Redis.current.lrange("#{$channel}_users", -1, -1).first
    user ? "<@#{user}>" : 'whoever is on dev support'
  end

  # Mid-day (~2pm) reminder for the on-support dev: how many are open vs closed
  # today, then a line per still-open request. Silent when nothing is open.
  def self.post_nudge
    open = SupportRequest.open_requests
    return if open.empty?

    closed = SupportRequest.metrics_for_day(date: Date.today)[:closed]
    summary = "Mid-day nudge (#{current_support_dev_mention}): #{open.length} open, #{closed} closed"
    lines = open.map { |r| format_request_line(r) }
    post("#{summary}\n#{lines.join("\n")}")
  end

  # End-of-day wrap-up, framed as a light service update. Always posts, even on
  # an all-clear day.
  def self.post_end_of_day_summary
    metrics = SupportRequest.metrics_for_day(date: Date.today)
    open = SupportRequest.open_requests

    return post('All clear today — no dev-support requests came in. :tada:') if metrics[:count].zero? && open.empty?

    stats = "#{pluralize(metrics[:count], 'request')}, #{metrics[:closed]} closed, " \
            "#{open.length} carrying into tomorrow"
    lines = ["Dev-support wrap-up for today: #{stats}"]

    unless open.empty?
      lines << ''
      lines << 'Still open:'
      open.each { |r| lines << format_request_line(r) }
    end

    post(lines.join("\n"))
  end

  def self.pluralize(count, noun)
    "#{count} #{noun}#{'s' unless count == 1}"
  end

  # Post to the support channel. unfurl_* are disabled so the Slack archive
  # links in request lines don't each render a bulky message-preview card.
  def self.post(text)
    $slack_client.chat_postMessage(channel: $channel, text:, unfurl_links: false, unfurl_media: false)
  end

  def self.created_today?(request)
    SupportRequest.epoch_to_date(request['created_at']) == Date.today
  end

  SNIPPET_LENGTH = 60

  def self.format_request_line(request)
    age = format_duration(Time.now.to_i - request['created_at'].to_f)
    "• #{message_link(request)} from <@#{request['user']}> — opened #{age} ago"
  end

  # A short, clickable label for the request's message: the truncated request
  # text linking to the Slack archive permalink. Slack renders <url|label> as a
  # hyperlink, so the raw URL never shows. Falls back to a generic label when
  # the request has no stored text.
  def self.message_link(request)
    "<#{archive_url(request)}|#{request_snippet(request)}>"
  end

  def self.request_snippet(request)
    text = request['text'].to_s.strip.tr("\n", ' ')
    return 'view request' if text.empty?

    snippet = text[0, SNIPPET_LENGTH]
    snippet += '…' if text.length > SNIPPET_LENGTH
    # Escape the few chars Slack treats specially inside link labels.
    "“#{snippet.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')}”"
  end

  def self.archive_url(request)
    ts = request['created_at'].to_s
    "https://slack.com/archives/#{request['channel']}/p#{ts.delete('.')}"
  end

  def self.format_duration(seconds)
    return 'n/a' if seconds.nil?

    seconds = seconds.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    return "#{hours}h #{minutes}m" if hours.positive?

    "#{minutes}m"
  end
end
