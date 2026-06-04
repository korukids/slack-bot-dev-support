require 'date'

class UserRegister
  DAY_KEYS = %w[sun mon tue wed thu fri sat].freeze
  DEFAULT_WORK_DAYS = %w[mon tue wed thu fri].freeze

  def self.add(user:, channel:)
    return "You've already registered <@#{user}>!" if user_registered?(channel, user)

    Redis.current.lpush("#{channel}_users", user)
    "Thanks for registering <@#{user}>!"
  end

  def self.remove(user:, channel:)
    return "<@#{user}> is not registered" unless list(channel:).include?(user)

    Redis.current.lrem("#{channel}_users", 0, user)
    Redis.current.del(user_meta_key(channel, user))
    "<@#{user}> has been deregistered"
  end

  def self.list(channel:)
    list_active(channel:)
  end

  # Rotate the current assignee (the tail) to the head, then skip past anyone
  # not working today. Returns the new assignee, or nil if nobody is eligible.
  def self.skip(channel:)
    Redis.current.rpoplpush("#{channel}_users", "#{channel}_users")
    advance_until_eligible(channel:)
  end

  def self.list_active(channel:)
    Redis.current.lrange("#{channel}_users", 0, 200)
  end

  def self.user_registered?(channel, user)
    list(channel:).include?(user)
  end

  def self.user_meta_key(channel, user)
    "#{channel}_user:#{user}"
  end

  def self.user_meta(channel:, user:)
    Redis.current.hgetall(user_meta_key(channel, user))
  end

  def self.work_days(channel:, user:)
    stored = user_meta(channel:, user:)['work_days']
    return DEFAULT_WORK_DAYS if stored.nil? || stored.empty?

    stored.split(',')
  end

  def self.set_work_days(channel:, user:, days:)
    Redis.current.hset(user_meta_key(channel, user), 'work_days', days.join(','))
  end

  def self.reset_work_days(channel:, user:)
    Redis.current.hdel(user_meta_key(channel, user), 'work_days')
  end

  def self.away_until(channel:, user:)
    raw = user_meta(channel:, user:)['away_until']
    return nil if raw.nil? || raw.empty?

    Date.parse(raw)
  rescue ArgumentError
    nil
  end

  def self.set_away_until(channel:, user:, date:)
    Redis.current.hset(user_meta_key(channel, user), 'away_until', date.to_s)
  end

  def self.clear_away(channel:, user:)
    Redis.current.hdel(user_meta_key(channel, user), 'away_until')
  end

  def self.eligible?(channel:, user:, date: Date.today)
    away = away_until(channel:, user:)
    return false if away && away >= date

    work_days(channel:, user:).include?(DAY_KEYS[date.wday])
  end

  # Rotate an ineligible tail to the head until the tail is eligible, looping at
  # most once around the list. Returns the chosen user id, or nil if nobody is
  # eligible (the list is left in its original order in that case).
  def self.advance_until_eligible(channel:, date: Date.today)
    users_key = "#{channel}_users"

    list_active(channel:).length.times do
      tail = Redis.current.lrange(users_key, -1, -1).first
      return tail if tail.nil? || eligible?(channel:, user: tail, date:)

      Redis.current.rpoplpush(users_key, users_key)
    end

    nil
  end

  # Assign a specific user. The current assignee (the old tail) is sent to the
  # head — the back of the line — so they return on the next full cycle. Other
  # users keep their place; only the displaced assignee loses their turn.
  def self.assign_to_user(channel:, user:)
    return { status: :not_registered } unless user_registered?(channel, user)

    active = list_active(channel:)
    return { status: :already_assigned } if active.last == user

    previous = active.last

    Redis.current.lrem("#{channel}_users", 0, user)
    if previous
      Redis.current.lrem("#{channel}_users", 0, previous)
      Redis.current.lpush("#{channel}_users", previous)
    end
    Redis.current.rpush("#{channel}_users", user)

    { status: :assigned, previous: }
  end
end
