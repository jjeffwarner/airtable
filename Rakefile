require 'rubocop/rake_task'

task default: %w[lint test]

RuboCop::RakeTask.new(:lint) do |task|
  task.patterns = ['lib/**/*.rb', 'test/**/*.rb']
  task.fail_on_error = false
end

desc "use with rake run['file_name.csv']"
task :run, [:file_name] do |t, args|
  puts 'Update actual data'
  `cp .env-collab-projects .env`
  file_name = args[:file_name] || 'roadmap.csv'
  sh "ruby 'lib/update.rb' #{file_name}"
end

desc "use with rake play['file_name.csv']"
task :play, [:file_name] do |t, args|
  puts 'Update play data'
  `cp .env-play-collab .env`
  file_name = args[:file_name] || 'roadmap.csv'
  sh "ruby 'lib/update.rb' #{file_name}"
end

task :test do
  ruby 'test/update_test.rb'
end
