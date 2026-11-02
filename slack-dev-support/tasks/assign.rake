task :assign do
  SlackDevSupport::Schedule.run(:assign) { SlackDevSupport.assign }
end
