task :support_nudge do
  SlackDevSupport::Schedule.run(:support_nudge) { SlackDevSupport.post_nudge }
end
