task :assign_prod_design do
  t = Time.now
  SlackDevSupport.assign_prod_design if t.tuesday?
end
