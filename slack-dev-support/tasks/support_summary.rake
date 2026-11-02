task :support_summary do
  SlackDevSupport::Schedule.run(:support_summary) { SlackDevSupport.post_end_of_day_summary }
end
