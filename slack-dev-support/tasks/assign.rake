task :assign do
  t = Time.now
  unless t.saturday? || t.sunday?
    SlackDevSupport.assign
  end
end