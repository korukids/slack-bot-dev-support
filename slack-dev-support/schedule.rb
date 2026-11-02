require 'redis'

# Decides whether a scheduled task should post *now*, in UK local time.
#
# External schedulers (Heroku Scheduler, cron on a UTC box) can't follow
# GMT/BST, so instead the scheduler triggers each task every hour and this gate
# lets it through only during its local-time slot. A slot is open for an hour
# from its start (tolerating a late-starting scheduler run), and a Redis claim
# makes sure each slot posts at most once per day even if the task fires more
# than once inside it.
module SlackDevSupport
  module Schedule
    # Local (Europe/London) start times for each task's slot(s).
    SLOTS = {
      assign: ['09:00'],
      support_nudge: ['11:00', '15:00'],
      support_summary: ['17:30']
    }.freeze

    WINDOW_SECONDS = 60 * 60
    CLAIM_TTL_SECONDS = 2 * 24 * 60 * 60

    # The slot (e.g. "09:00") that's currently open for task, or nil. Weekends
    # never have an open slot.
    def self.open_slot(task, now: Time.now)
      return if now.saturday? || now.sunday?

      SLOTS.fetch(task).find do |slot|
        hour, min = slot.split(':').map(&:to_i)
        start = Time.new(now.year, now.month, now.day, hour, min, 0)
        now >= start && now < start + WINDOW_SECONDS
      end
    end

    # Yields when task is due now and hasn't already posted for this slot today.
    # FORCE=1 bypasses both checks, for running a task by hand.
    def self.run(task, now: Time.now, force: ENV['FORCE'] == '1')
      return yield if force

      slot = open_slot(task, now:)
      return unless slot && claim(task, now.to_date, slot)

      yield
    end

    def self.claim(task, date, slot)
      key = "#{$channel}_scheduled:#{task}:#{date.iso8601}:#{slot}"
      Redis.current.set(key, '1', nx: true, ex: CLAIM_TTL_SECONDS)
    end
  end
end
