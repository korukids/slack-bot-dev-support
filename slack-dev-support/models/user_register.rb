class UserRegister
  def self.add(user:, channel:)
    return "You've already registered <@#{user}>!" if user_registered?(channel, user)

    Redis.current.lpush("#{channel}_users", user)
    "Thanks for registering <@#{user}>!"
  end

  def self.remove(user:, channel:)
    return "<@#{user}> is not registered" unless list(channel:).include?(user)

    Redis.current.lrem("#{channel}_users", 0, user)
    "<@#{user}> has been deregistered"
  end

  def self.list(channel:)
    list_active(channel:)
  end

  # Rotate the current assignee (the tail) to the head and return the new tail.
  def self.skip(channel:)
    Redis.current.rpoplpush("#{channel}_users", "#{channel}_users")
    list_active(channel:).last
  end

  def self.list_active(channel:)
    Redis.current.lrange("#{channel}_users", 0, 200)
  end

  def self.user_registered?(channel, user)
    list(channel:).include?(user)
  end
end
