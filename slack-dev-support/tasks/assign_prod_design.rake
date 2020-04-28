task :assign_prod_design do
  t = Time.now
  if t.tuesday?
    SlackDevSupport.assign_prod_design
  end
end
