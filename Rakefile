#!/usr/bin/env rake
require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end
task :default => :test

desc "clean up"
task :clean do
  FileUtils.rm(FileList["samples/**/*.db"], force: true, verbose: true)
end

desc "install gems for running samples"
task :samples do
  system('bundle install --gemfile=samples/samples.gemfile')
end