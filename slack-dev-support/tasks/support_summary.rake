task :support_summary do
  t = Time.now
  SlackDevSupport.post_end_of_day_summary unless t.saturday? || t.sunday?
end
