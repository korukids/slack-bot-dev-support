task :support_nudge do
  t = Time.now
  SlackDevSupport.post_nudge unless t.saturday? || t.sunday?
end
