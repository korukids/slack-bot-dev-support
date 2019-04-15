task :assign do
  t = Time.now
  unless t.saturday? || t.sunday?
    SlackDevSupport::Bot.assign
  end
end