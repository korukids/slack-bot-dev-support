task :assign do
  t = Time.now
  SlackDevSupport.assign unless t.saturday? || t.sunday?
end
