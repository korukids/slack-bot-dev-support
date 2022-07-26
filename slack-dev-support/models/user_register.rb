class UserRegister
  def self.add(user:, channel:)
    return "You've already registered <@#{user}>!" if user_registered?(channel, user)

    Redis.current.lpush("#{channel}_users", user)
    "Thanks for registering <@#{user}>!"
  end

  def self.remove(user:, channel:)
    return "<@#{user}> is not registered" unless list(channel:).include?(user)

    list_with_user = if list_not_applicable(channel:).include?(user)
                       "#{channel}_not_applicable"
                     else
                       "#{channel}_users"
                     end
    Redis.current.lrem(list_with_user, 0, user)
    "<@#{user}> has been deregistered"
  end

  def self.list(channel:)
    list_not_applicable(channel:) + list_active(channel:)
  end

  def self.skip(channel:)
    channel_list = list(channel:)
    return unless channel_list.count > 1

    Redis.current.rpoplpush("#{channel}_users", "#{channel}_not_applicable")

    cycled_list = list(channel:)
    cycled_list.last
  end

  def self.list_active(channel:)
    Redis.current.lrange("#{channel}_users", 0, 200)
  end

  def self.list_not_applicable(channel:)
    Redis.current.lrange("#{channel}_not_applicable", 0, 200)
  end

  def self.user_registered?(channel, user)
    list(channel:).include?(user)
  end
end
