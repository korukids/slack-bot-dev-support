require 'date'

# Tracks dev-support requests landing in the support channel through their
# lifecycle (New -> Investigating -> Acknowledged -> Closed) and exposes daily
# aggregates. Pure Redis, no Slack — so it can be driven directly from specs.
#
# Redis layout:
#   support:req:{ts}        Hash    one request (created_at, user, text, channel,
#                                   investigating_at, acknowledged_at,
#                                   acknowledged_by, closed_at). 90-day TTL.
#   support:day:{YYYY-MM-DD} Set     ts's created that day (cohort-by-creation).
#                                    90-day TTL, refreshed on each add.
#   support:open            Set     currently-open ts's, for fast carryover.
#
# All timestamps are epoch seconds (Slack `ts` is epoch). Day bucketing uses the
# server-local date, consistent with the rest of the codebase (bare Date.today).
class SupportRequest
  TTL_SECONDS = 90 * 24 * 60 * 60
  OPEN_KEY = 'support:open'.freeze
  TEXT_SNIPPET_LENGTH = 120

  def self.create_request(ts:, user:, text:, channel:)
    key = req_key(ts)
    return if exists?(ts)

    Redis.current.mapped_hmset(key,
                               'created_at' => ts,
                               'user' => user,
                               'text' => text.to_s[0, TEXT_SNIPPET_LENGTH],
                               'channel' => channel)
    Redis.current.expire(key, TTL_SECONDS)

    day = day_key(epoch_to_date(ts))
    Redis.current.sadd(day, ts)
    Redis.current.expire(day, TTL_SECONDS)

    Redis.current.sadd(OPEN_KEY, ts)
  end

  def self.mark_investigating(ts:, at:)
    return unless exists?(ts)

    Redis.current.hset(req_key(ts), 'investigating_at', at)
  end

  def self.clear_investigating(ts:)
    return unless exists?(ts)

    Redis.current.hdel(req_key(ts), 'investigating_at')
  end

  # First reply wins — only set if not already acknowledged.
  def self.mark_acknowledged(ts:, by:, at:)
    return unless exists?(ts)
    return if Redis.current.hexists(req_key(ts), 'acknowledged_at')

    Redis.current.mapped_hmset(req_key(ts), 'acknowledged_at' => at, 'acknowledged_by' => by)
  end

  def self.mark_closed(ts:, at:)
    return unless exists?(ts)

    Redis.current.hset(req_key(ts), 'closed_at', at)
    Redis.current.srem(OPEN_KEY, ts)
  end

  def self.reopen(ts:)
    return unless exists?(ts)

    Redis.current.hdel(req_key(ts), 'closed_at')
    Redis.current.sadd(OPEN_KEY, ts)
  end

  def self.get(ts:)
    return nil unless exists?(ts)

    Redis.current.hgetall(req_key(ts))
  end

  # Open requests, newest first. Lazily drops any whose hash has expired/vanished.
  def self.open_requests
    Redis.current.smembers(OPEN_KEY).filter_map do |ts|
      hash = get(ts:)
      if hash.nil?
        Redis.current.srem(OPEN_KEY, ts)
        next
      end
      hash
    end.sort_by { |h| -h['created_at'].to_f }
  end

  def self.requests_for_day(date:)
    Redis.current.smembers(day_key(date)).filter_map { |ts| get(ts:) }
  end

  # Aggregates over the cohort of requests *created* on `date`.
  # avg_*_seconds are over the requests that reached that state (nil if none).
  def self.metrics_for_day(date:)
    requests = requests_for_day(date:)

    closed = requests.select { |r| r['closed_at'] }
    acked = requests.select { |r| r['acknowledged_at'] }

    {
      count: requests.length,
      closed: closed.length,
      open: requests.length - closed.length,
      avg_ack_seconds: average(acked.map { |r| r['acknowledged_at'].to_f - r['created_at'].to_f }),
      avg_close_seconds: average(closed.map { |r| r['closed_at'].to_f - r['created_at'].to_f })
    }
  end

  # redis-rb's #exists returns a boolean or an integer count depending on the
  # exists_returns_integer setting. Normalise both (integer 0 is truthy in Ruby).
  def self.exists?(ts)
    result = Redis.current.exists(req_key(ts))
    result.is_a?(Integer) ? result.positive? : result
  end

  def self.req_key(ts)
    "support:req:#{ts}"
  end

  def self.day_key(date)
    "support:day:#{date}"
  end

  def self.epoch_to_date(ts)
    Time.at(ts.to_f).to_date
  end

  def self.average(values)
    return nil if values.empty?

    values.sum / values.length
  end
end
