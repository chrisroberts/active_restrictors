module ActiveRestrictor
  module ClassMethods

    # name:: Name of restrictor. For non-basic types this must be the name of the association.
    # opts:: Options hash. Valid options:
    #   :type:: Should be set to :basic when applying simple condition only
    #   :condition:: Condition string applied to User
    #   :class:: Class restriction is based on
    #   :value:: Attribute name of value to display
    #   :multiple:: Allow user to select multiple items for restriction
    #   :include_blank:: Include blank option in restriction selection
    #   :user_custom:: Block that returns User scope (passed: User scope, self instance)
    #   :user_association:: Name of association on user
    #   :model_custom:: Block that returns Model scope (passed: self instance, User instance)
    #   :enabled:: If restrictor is enabled. Must be boolean value or a callable object that returns boolean value
    #   :default_view_all:: If user has not been assigned a restrictor, they see all unless set to false
    #   :user_values_only:: User instance. Set this if you only want values set against user to be selectable
    # Adds restrictions to Model
    # NOTE: Basic type signifies that condition is forced without
    # user interaction. This means no select options will be used
    # as basic restrictors are never seen by the user. Basic restrictors
    # are applied directly against the user model.
    def add_restrictor(name, opts={})
      self.restrictors ||= []
      new_opts = {:name => name, :id => :id, :enabled => true, :type => :full, :include => []}.merge(opts)
      new_opts[:include] = [new_opts[:include]] unless new_opts[:include].is_a?(Array)
      new_opts[:include].push(name) unless new_opts[:include].map(&:to_s).include?(name.to_s)
      self.restrictors.push(new_opts)
      if(new_opts[:type] == :full)
        self.class_eval do
          # This just creates a helper that will grab activerecord
          # instance from passed in IDs for applied restriction
          alias_method "original_#{name}=".to_sym, "#{name}=".to_sym
          define_method("#{name}=") do |args|
            args = (args.is_a?(Array) ? args : Array(args)).find_all{|arg|arg.present?}
            new_args = []
            ids = []
            args.each do |item|
              if(item.is_a?(ActiveRecord::Base) || (defined?(ActiveRecord::Relation) && item.is_a?(ActiveRecord::Relation)))
                new_args << item
              else
                ids << item.to_i
              end
            end
            new_args += new_opts[:class].find(ids) unless ids.empty?
            self.send("original_#{name}=".to_sym, new_args)
          end
        end
      end
    end

    # Returns restrictors not of type :basic
    def full_restrictors
      self.restrictors.find_all{|restrictor| restrictor[:type] != :basic && check_enabled(restrictor[:enabled]) == true}
    end

    # Returns restrictors of type :basic
    def basic_restrictors
      self.restrictors.find_all{|restrictor| restrictor[:type] == :basic && check_enabled(restrictor[:enabled]) == true}
    end

    # Returns all restrictors that are currently in enabled state
    def enabled_restrictors
      self.restrictors.find_all{|restrictor| check_enabled(restrictor[:enabled]) == true}
    end

    # hash:: Restrictor hash
    # Provides class of restrictor
    def restrictor_class(hash)
      if(restrictor[:class].present?)
        restrictor[:class]
      else
        self.relect_on_association(restrictor[:name]).klass
      end
    end

    private

    # arg:: Enabled argument (generally: restrictor[:enabled])
    # Test if enabled is true via value or block evaluation
    def check_enabled(arg)
      if(arg)
        if(arg.respond_to?(:call))
          arg.call
        else
          arg
        end
      else
        false
      end
    end
  end

  module InstanceMethods

    # hash:: Restrictor hash
    # Provides class of restrictor
    def restrictor_class(hash)
      self.class.restrictor_class(hash)
    end

    # Returns restrictors not of type :basic
    def full_restrictors
      self.class.full_restrictors
    end

    # Returns restrictors of type :basic
    def basic_restrictors
      self.class.basic_restrictors
    end

    # Returns all restrictors taht are currently in enabled status
    def enabled_restrictors
      self.class.enabled_restrictors
    end

    # Returns User scope with all restrictors applied
    def allowed_users
      user_scope = User.scoped
      enabled_restrictors.each do |restrictor|
        next if restrictor[:user_custom]
        if(restrictor[:include].is_a?(ActiveRecord::Relation))
          user_scope = user_scope.merge(restrictor[:include])
        elsif(restrictor[:include].present?)
          user_scope = user_scope.joins(restrictor[:include])
        end
        if(restrictor[:condition].is_a?(ActiveRecord::Relation))
          user_scope = user_scope.merge(restrictor[:condition])
        elsif(restrictor[:condition].respond_to?(:call))
          user_scope = user_scope.merge(restrictor[:condition].call)
        elsif(restrictor[:condition].present?)
          user_scope = user_scope.where(restrictor[:condition])
        end
        unless(restrictor[:type] == :basic)
          user_scope = user_scope.where("#{restrictor[:table_name] || restrictor_class(restrictor).table_name}.id IN (#{self.send(restrictor[:name]).scoped.select(:id).to_sql})")
        end
      end
      if((methods = enabled_restrictors.find_all{|res| res[:user_custom]}).size > 0)
        user_scope = methods.inject(user_scope){|result,func| func.call(result, self)}
      end
      user_scope
    end
  end

  def self.included(klass)
    # Patch up the model we have been called on
    ([klass] + klass.descendants).compact.each do |base|
      cattr_accessor :restrictors
      
      extend ClassMethods
      include InstanceMethods

      scope :allowed_for, lambda{|*args|
        user = args.detect{|item|item.is_a?(User)}
        where("#{table_name}.id IN (#{user.send("allowed_#{base.name.tableize}").select(:id).to_sql})")
      }
    end
    # Patch up the user to provide restricted methods
    ([User] + User.descendants).compact.each do
      # This patches a method onto the User instance to
      # provide access to the allowed instance of the model
      # in use. For example, if the restrictor module is
      # included into the Fubar model, it will
      # provide User#allowed_fubars
      define_method("allowed_#{klass.name.tableize}") do
        # First we perform a basic check against the User to see
        # if this user instance is even allowed by default
        user_scope = User.scoped
        klass.basic_restrictors.each do |restriction|
          if(restriction[:condition].is_a?(ActiveRecord::Relation))
            user_scope = user_scope.merge(restriction[:condition])
          elsif(restriction[:condition].respond_to?(:call))
            user_scope = user_scope.merge(restriction[:condition].call)
          elsif(restriction[:condition].present?)
            user_scope = user_scope.where(restriction[:condition])
          end
          if(restriction[:include].is_a?(ActiveRecord::Relation))
            user_scope = user_scope.merge(restriction[:include])
          elsif(restriction[:include].present?)
            user_scope = user_scope.join(restriction[:include])
          end
        end
        if(user_scope.count > 0)
          scope = klass.scoped
          klass.full_restrictors.each do |restrictor|
            next if restrictor[:include].blank? || restrictor[:model_custom].present?
            rtable_name = restrictor[:table_name] || restrictor_class(restrictor).table_name
            r_scope = self.send(restrictor[:include]).scoped.select("#{rtable_name}.id")
            r_scope.arel.ast.cores.first.projections.delete_at(0) # gets rid of the association_name.* rails insists upon
            if(restrictor[:default_view_all])
              scope = scope.includes(restrictor[:name]) if restrictor[:name].present?
            else
              scope = scope.joins(restrictor[:name]) if restrictor[:name].present?
            end
            scope = scope.where(
              "#{rtable_name}.id IN (#{r_scope.to_sql})#{
                " OR #{rtable_name}.id IS NULL" if restrictor[:default_view_all]
              }"
            )
            if((methods = klass.restrictors.find_all{|res| res[:model_custom]}).size > 0)
              scope = methods.inject(scope){|result,func| func.call(result, self)}
            end
          end
          scope
        else
          klass.where('false')
        end
      end
    end
  end
end
