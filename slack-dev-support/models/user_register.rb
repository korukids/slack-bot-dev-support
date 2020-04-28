class UserRegister
  def self.add(user:,channel:)
    return "You've already registered <@#{user}>!" if user_registered?(channel, user)

    Redis.current.lpush("#{channel}_users", user)
    "Thanks for registering <@#{user}>!"
  end

  def self.list(channel:)
    self.list_not_applicable(channel: channel) + self.list_active(channel: channel)
  end

  private

  def self.list_active(channel:)
    Redis.current.lrange("#{channel}_users", 0, 200)
  end

  def self.list_not_applicable(channel:)
    Redis.current.lrange("#{channel}_not_applicable", 0, 200)
  end

  def self.user_registered?(channel, user)
    self.list(channel: channel).include?(user)
  end
end
