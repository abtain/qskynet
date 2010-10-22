require 'rake'

namespace :deploy do
  desc "Sync static files"
  task :static do
    `s3sync -dvpr /Users/quellhorst/Projects/qskynet/ q3.abtain.com:`
  end
end

desc "Run all tasks"
task :all => ["deploy:static"]
