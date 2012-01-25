require 'rubygems'
require 'bundler/setup'
unless(RUBY_PLATFORM == 'java')
  require 'sqlite3'
end
require 'active_record'
require 'active_record/migration'
require 'benchmark'
require 'active_restrictors'
require 'minitest/autorun'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)
load File.join(File.expand_path(File.dirname(__FILE__)), 'model_definitions.rb')
