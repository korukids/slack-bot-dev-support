namespace :assign do
  task :product_design_chair do
    t = Time.now
    if t.tuesday? || t.thursday?
      SlackDevSupport.assign_product_design_chair
    end
  end
end
