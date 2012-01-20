$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'active_restrictors/version'

Gem::Specification.new do |s|
  s.name = 'active_restrictors'
  s.version = ActiveRestrictors::VERSION.to_s
  s.summary = 'Restrictors for Models'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'http://bitbucket.org/chrisroberts/active_restrictors'
  s.description = 'Restrictors for Models'
  s.add_dependency 'activerecord', '~> 3.0'
  s.require_path = 'lib'
  s.extra_rdoc_files = ['README.rdoc', 'CHANGELOG.rdoc']
  s.files = Dir.glob('**/*')
end
