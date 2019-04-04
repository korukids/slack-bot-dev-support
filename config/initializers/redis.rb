Redis.current = Redis.new(url: ENV.fetch('REDISTOGO_URL', "redis://localhost:6379/"))
