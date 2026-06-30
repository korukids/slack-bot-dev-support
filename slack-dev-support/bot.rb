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
    $slack_client.chat_postMessage(channel: $channel, text:)
  end

  # Appended to the daily message when requests are still open from previous
  # days, so nothing silently rolls over. nil when there's no carryover.
  def self.carryover_note
    carried = SupportRequest.open_requests.reject { |r| created_today?(r) }
    return if carried.empty?

    lines = carried.map { |r| format_request_line(r) }
    "Still open from previous days:\n#{lines.join("\n")}"
  end

  # The morning post. Names today's dev and sets expectations: we review
  # through the day, and urgent things should be pinged directly.
  def self.assignment_message(user)
    unless user
      return 'No-one is on dev support today. Please post requests here and ' \
             'ping the team directly if something is urgent.'
    end

    mention = "<@#{user}>"
    ":wave: #{mention} is on dev support today. We'll review requests through the day and " \
      "get back to you — if something needs urgent attention, ping #{mention} directly. " \
      'Just post your request here and we\'ll pick it up.'
  end

  # Today's on-support dev — the tail of the rotation (same convention the daily
  # assignment uses). Returns a Slack mention, or a neutral phrase if empty.
  def self.current_support_dev_mention
    user = Redis.current.lrange("#{$channel}_users", -1, -1).first
    user ? "<@#{user}>" : 'whoever is on dev support'
  end

  # Mid-day status note: requests still open or awaiting a first response.
  # Silent when everything is clear.
  def self.post_nudge
    open = SupportRequest.open_requests
    return if open.empty?

    awaiting = open.reject { |r| r['acknowledged_at'] }
    summary = "Quick dev-support update — #{open.length} request(s) still open"
    summary += ", #{awaiting.length} awaiting a first response" unless awaiting.empty?
    lines = open.map { |r| format_request_line(r) }
    text = "#{summary} (#{current_support_dev_mention} is on support today):\n#{lines.join("\n")}"
    $slack_client.chat_postMessage(channel: $channel, text:)
  end

  # End-of-day wrap-up, framed as a light service update. Always posts, even on
  # an all-clear day.
  def self.post_end_of_day_summary
    metrics = SupportRequest.metrics_for_day(date: Date.today)
    open = SupportRequest.open_requests

    if metrics[:count].zero? && open.empty?
      text = 'All clear today — no dev-support requests came in. :tada:'
      return $slack_client.chat_postMessage(channel: $channel, text:)
    end

    lines = ['Dev-support wrap-up for today:',
             "• Requests: #{metrics[:count]}",
             "• Resolved: #{metrics[:closed]}",
             "• Carrying into tomorrow: #{open.length}",
             "• Typical first response: #{format_duration(metrics[:avg_ack_seconds])}",
             "• Typical resolution: #{format_duration(metrics[:avg_close_seconds])}"]

    unless open.empty?
      lines << 'Still open:'
      open.each { |r| lines << format_request_line(r) }
    end

    $slack_client.chat_postMessage(channel: $channel, text: lines.join("\n"))
  end

  def self.created_today?(request)
    SupportRequest.epoch_to_date(request['created_at']) == Date.today
  end

  def self.format_request_line(request)
    age = format_duration(Time.now.to_i - request['created_at'].to_f)
    "• #{message_link(request)} from <@#{request['user']}> — #{request_state(request)}, opened #{age} ago"
  end

  def self.request_state(request)
    return 'closed' if request['closed_at']
    return 'acknowledged' if request['acknowledged_at']
    return 'investigating' if request['investigating_at']

    'new'
  end

  def self.message_link(request)
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
