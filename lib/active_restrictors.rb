require 'active_restrictors/version'

if(defined?(ActiveRecord::Relation))
  require 'active_restrictors/active_restrictor'
end
if(defined?(ActionView))
  require 'active_restrictors/active_restrictor_views'
end
