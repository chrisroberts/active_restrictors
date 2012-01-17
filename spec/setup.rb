$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
require 'rubygems'
require 'bundler/setup'
require 'active_record'
if(RUBY_PLATFORM == 'java')
  require 'jdbc/sqlite3'
else
  require 'sqlite3'
end
require 'active_restrictors'
require 'minitest/autorun'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)
load File.join(File.expand_path(File.dirname(__FILE__)), 'model_definitions.rb')
