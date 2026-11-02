# The team works UK hours, but Heroku dynos run in UTC. Pin the process to
# Europe/London so Time.now / Date.today follow GMT/BST automatically — the
# scheduled-task gate (SlackDevSupport::Schedule) and day bucketing rely on it.
# Deliberately unconditional: an inherited TZ (e.g. TZ=UTC) would silently
# reintroduce the hour-off-after-DST bug.
ENV['TZ'] = 'Europe/London'
