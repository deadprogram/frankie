require 'rubygems'
require 'rake/testtask'
require 'rake/rdoctask'
require 'echoe'

task :default => :test
 
Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files += ["README.rdoc"]
  rd.rdoc_files += Dir.glob("lib/**/*.rb")
  rd.rdoc_dir = 'doc'
end
 
Rake::TestTask.new do |t|
  ENV['SINATRA_ENV'] = 'test'
  t.pattern = File.dirname(__FILE__) + "/test/*_test.rb"
end
 
Echoe.new("frankie") do |p|
  p.author = "Ron Evans"
  p.summary = "Easy creation of Facebook applications in Ruby using plugin for Sinatra web framework that integrates with Facebooker gem."
  p.url = "http://facethesinatra.com/"
  p.dependencies = ["sinatra >=0.2.2", "facebooker >=0.9.5"]
  p.install_message = "*** Frankie was installed ***"
  p.include_rakefile = true
end

