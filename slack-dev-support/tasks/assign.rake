task :assign do
  t = Time.now
  unless t.saturday? || t.sunday? do
    SlackDevSupport::Bot.assign
  end
end