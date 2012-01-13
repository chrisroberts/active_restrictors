module ActiveRestrictor
  module ClassMethods

    # name:: Name of restrictor. For non-basic types this must be the name of the association.
    # opts:: Options hash. Valid options:
    #   :type:: :full, :implicit, :basic_model, :basic_user
    #   :class:: Class restriction is based on if not guessable
    #   :enabled:: If restrictor is enabled. Must be boolean value or a callable object that returns boolean value
    #   :scope:: Scope or callable block returning scope
    #   :views =>
    #     :value:: Attribute name of value to display
    #     :multiple:: Multiple assignments allowed
    #     :include_blank:: Allow assignments to be unset
    #     :user_values_only:: User instance. Set this if you only want values set against user to be selectable
    #     :id:: Value method for selection (defaults to :id)
    #   :user_association:: Name of association on user (if different from restrictor name)
    #   :user_custom:: Block that returns User scope (passed: User scope, self instance) - Used when generic scope building is lacking
    #   :model_custom:: Block that returns Model scope (passed: self instance, User instance) - Used when generic scope building is lacking
    #   :default_allowed_all:: If source instance has no restriction assigned, it is viewable
    #   :default_view_all:: Alias for :default_allowed_all
    # Adds restrictions to Model
    # NOTE: Basic types are run directly against the model culminating in a count to see if it is valid (ex for :basic_user: User.where(:allowed_to_do_stuff => true))
    #       Implicit type is run directly against the source model. (ex: Fubar.includes(:feebar).where(:feebars => {:user_id => User.current_user.id}))
    #       Full is a full restrictor using join tables and provides view helpers for management
    def add_restrictor(name, opts={})
      self.restrictors ||= []
      new_opts = {:name => name, :enabled => true, :type => :full, :scope => self.scoped, :default_allowed_all => false}.merge(opts)
      new_opts[:views] ||= {}
      new_opts = map_deprecated_hash(new_opts)
      new_opts[:views][:id] ||= :id
      if(new_opts[:type] == :full)
        raise 'Value must be defined for association to generate views' unless new_opts[:views][:value].present?
      end
      new_opts[:class] = restrictor_class(new_opts)
      self.restrictors.push(new_opts)
    end

    # TODO: Add in proper mapping plus scope building
    def map_deprecated_hash(hsh)
      hsh[:type] = :basic_user if hsh[:type] == :basic
      hsh[:scope] = self.class._restrictor_custom_user_class.where(hsh.delete(:condition)) if hsh[:condition].present?
      [:value, :multiple, :include_blank, :user_values_only, :id].each do |v_opt|
        hsh[:views][v_opt] = hsh.delete(v_opt) if hsh[v_opt].present?
      end
      hsh[:default_allowed_all] = hsh.delete(:default_view_all) if hsh.has_key?(:default_view_all)
      hsh
    end

    # Returns restrictors of type: :full
    # NOTE: Returns enabled by default. Provide :include_disabled to get all
    def full_restrictors(*args)
      self.restrictors.find_all do |restrictor| 
        restrictor[:type] == :full &&
          (args.include?(:include_disabled) || check_enabled(restrictor[:enabled]) == true)
      end
    end

    # Returns restrictors of type :basic_model
    # NOTE: Returns enabled by default. Provide :include_disabled to get all
    def basic_model_restrictors(*args)
      self.restrictors.find_all do |restrictor| 
        restrictor[:type] == :basic_model && 
          (args.include?(:include_disabled) || check_enabled(restrictor[:enabled]) == true)
      end
    end

    # Returns restrictors of type :basic_user
    # NOTE: Returns enabled by default. Provide :include_disabled to get all
    def basic_user_restrictors(*args)
      self.restrictors.find_all do |restrictor| 
        restrictor[:type] == :basic_user && 
          (args.include?(:include_disabled) || check_enabled(restrictor[:enabled]) == true)
      end
    end

    # Returns restrictors of type :implicit
    def implicit_restrictors(*args)
      self.restrictors.find_all do |restrictor|
        restrictor[:type] == :implicit &&
          check_enabled(restrictor[:enabled]) == true
      end
    end

    # Returns all restrictors that are currently in enabled state
    def enabled_restrictors
      self.restrictors.find_all{|restrictor| check_enabled(restrictor[:enabled]) == true}
    end

    # hash:: Restrictor hash
    # Provides class of restrictor
    def restrictor_class(hash)
      if(hash[:class].present?)
        hash[:class]
      else
        if(hash[:type] == :basic_user)
          _restrictor_custom_user_class
        elsif(hash[:type] == :basic_model)
          self
        else
          n = self.reflect_on_association(hash[:name]).try(:klass)
          if(n.blank?)
            raise "Failed to location association for restrictor. Given: #{hash[:name]}. Please check assocation name."
          end
          n
        end
      end
    end

    def restrictor_user_scoping
      user_scope = _restrictor_custom_user_class
      basic_user_restrictors.each do |restrictor|
        user_scope = user_scope.merge(restrictor[:scope].respond_to?(:call) ? restrictor[:scope].call : restrictor[:scope])
      end
      user_scope
    end

    def restrictor_klass_scoping
      klass_scope = self.scoped
      (implicit_restrictors + basic_model_restrictors).each do |restrictor|
        klass_scope = klass_scope.merge(restrictor[:scope].respond_to?(:call) ? restrictor[:scope].call : restrictor[:scope])
      end
      klass_scope
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
    # NOTE: Returns enabled by default. Provide :include_disabled to get all
    def full_restrictors(*args)
      self.class.full_restrictors(*args)
    end

    # Returns restrictors of type :basic_user
    # NOTE: Returns enabled by default. Provide :include_disabled to get all
    def basic_user_restrictors(*args)
      self.class.basic_user_restrictors(*args)
    end

    # Returns restrictors of type :basic_model
    # NOTE: Returns enabled by default. Provide :include_disabled to get all
    def basic_model_restrictors(*args)
      self.class.basic_model_restrictors(*args)
    end

    # Returns restrictors of type :implict
    def implicit_restrictors
      self.class.implicit_restrictors
    end

    # Returns all restrictors taht are currently in enabled status
    def enabled_restrictors
      self.class.enabled_restrictors
    end

    # Grabs customizable user class
    def _restrictor_custom_user_class
      self.class._restrictor_custom_user_class
    end

    # Returns User scope with all restrictors applied
    def allowed_users
      klass_scope = self.class.restrictor_klass_scoping.where(:id => self.id)
      user_scope = self.class.restrictor_user_scoping
      if(klass_scope.count > 0)
        full_restrictors.each do |restrictor|
          unless(restrictor[:user_custom].present?)
            rtable_name = restrictor[:table_name] || restrictor[:class].table_name
            r_scope = self.send(restrictor[:name]).scoped.select("#{rtable_name}.id")
            # this next bit gets rid of the association_name.* rails insists upon and any extra cruft
            r_scope.arel.ast.cores.first.projections.delete_if{|item| item != "#{rtable_name}.id"}
            user_scope = user_scope.where(
              "#{rtable_name}.id IN (#{r_scope.to_sql})#{
                " OR #{rtable_name}.id IS NULL" if restrictor[:default_allowed_all]
              }"
            )
          else
            user_scope = restrictor[:user_custom].call(user_scope, self)
          end
        end
        user_scope
      else
        user_scope.where('false')
      end
    end
  end

  def self.included(klass)
    # Patch up the model we have been called on
    ([klass] + klass.descendants).compact.each do |base|
      base.class_eval do
        cattr_accessor :restrictors
        
        extend ClassMethods
        include InstanceMethods

        unless(base.singleton_methods.map(&:to_sym).include?(:_restrictor_custom_user_class))
          class << self
            # This can be overridden for customization
            def _restrictor_custom_user_class
              User
            end
          end
        end
        scope :allowed_for, lambda{|*args|
          user = args.detect{|item|item.is_a?(User)}
          if(user.present?)
            r_scope = user.send("allowed_#{base.name.tableize}").select("#{base.table_name}.id")
            r_scope.arel.ast.cores.first.projections.delete_if{|item| item != "#{base.table_name}.id"}
            where("#{table_name}.id IN (#{r_scope.to_sql})")
          else
            where('false')
          end
        }
      end
    end
    # Patch up the user to provide restricted methods
    ([klass._restrictor_custom_user_class] + klass._restrictor_custom_user_class.descendants).compact.each do |user_klass|
      user_klass.class_eval do
        # This patches a method onto the User instance to
        # provide access to the allowed instance of the model
        # in use. For example, if the restrictor module is
        # included into the Fubar model, it will
        # provide User#allowed_fubars
        define_method("allowed_#{klass.name.tableize}") do
          # First we perform a basic check against the User to see
          # if this user instance is even allowed by default
          user_scope = klass.restrictor_user_scoping.where(:id => self.id)
          if(user_scope.count > 0)
            scope = klass.restrictor_klass_scoping
            klass.full_restrictors.each do |restrictor|
              if(restrictor[:scope].present?)
                scope = scope.merge(restrictor[:scope].respond_to?(:call) ? restrictor[:scope].call : restrictor[:scope])
              end
              unless(restrictor[:model_custom].present?)
                scope = scope.includes(restrictor[:name])
                rtable_name = restrictor[:table_name] || restrictor[:class].table_name
                r_scope = self.send(restrictor[:user_association] || restrictor[:name]).scoped.select("#{rtable_name}.id") # This gives us valid joiners!
                # this next bit gets rid of the association_name.* rails insists upon and any extra cruft
                r_scope.arel.ast.cores.first.projections.delete_if{|item| item != "#{rtable_name}.id"}
                scope = scope.where(
                  "#{rtable_name}.id IN (#{r_scope.to_sql})#{
                    " OR #{rtable_name}.id IS NULL" if restrictor[:default_allowed_all]
                  }"
                )
              else
                scope = restrictor[:model_custom].call(scope, self)
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
end
