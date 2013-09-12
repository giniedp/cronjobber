# -*- encoding : utf-8 -*-
require 'rubygems'
require 'rake'

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'cronjobber'
    gem.summary = %Q{Cronjob for Rails}
    gem.description = %Q{Enables simple cronjobs for rails}
    gem.email = 'mail@ginie.eu'
    gem.homepage = 'https://github.com/giniedp/cronjobber'
    gem.authors = ['Alexander Gräfenstein']
    gem.license = 'MIT'
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake'
require 'rdoc/task'

require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "cronjobber #{version}"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
