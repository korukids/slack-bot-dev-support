class UserRegister
  def self.add(user:,channel:)
    return "You've already registered <@#{user}>!" if user_registered?(channel, user)

    Redis.current.lpush("#{channel}_users", user)
    "Thanks for registering <@#{user}>!"
  end

  def self.list(channel:)
    Redis.current.lrange("#{channel}_users", 0, 200)
  end

  private

  def self.user_registered?(channel, user)
    self.list(channel: channel).include?(user)
  end
end
