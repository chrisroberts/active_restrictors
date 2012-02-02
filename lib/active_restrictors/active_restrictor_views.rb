module ActiveRestrictors
  module View

    # obj:: Instance with restrictors enabled
    # args:: argument hash :
    #  :val_join:: string to join values with
    #  :include_disabled:: includes all restrictors
    # val_join:: String to join restictor values together
    # Provides array of enabled restrictors in the form of:
    # [[restrictor_name_label, string_of_restriction_values]]
    def display_full_restrictors(obj, *args)
      arg_h = args.last.is_a?(Hash) ? args.last : {}
      res = []
      if(args.size == 1 && args.first.is_a?(String))
        val_join = args.first
      else
        val_join = arg_h[:val_join] || '<br />'
      end
      if(obj.class.respond_to?(:full_restrictors))
        r_args = arg_h[:include_disabled] ? [:include_disabled] : []
        res = obj.class.full_restrictors(*r_args).map do |restrictor|
          [label(obj.class.name.camelize, restrictor[:name]),
            obj.send(restrictor[:name]).map(&restrictor[:views][:value].to_sym).join(val_join).html_safe]
        end
      end
      res
    end

    # obj:: Instance with restrictors enabled
    # form:: Form object to attach restrictor fields to
    # args:: Argument hash -> 
    #  :include_disabled:: includes all restrictors
    # Provides form items for restrictors in an array of format:
    # [[restrictor_name_label, form_selection_string]]
    def edit_full_restrictors(obj, form, args={})
      r_args = args[:include_disabled] ? [:include_disabled] : []
      if(obj.class.respond_to?(:full_restrictors))
        obj.class.full_restrictors(*r_args).map do |restrictor|
          if(restrictor[:views][:user_values_only])
            if(restrictor[:views][:user_values_only].respond_to?(:call))
              user = restrictor[:views][:user_values_only].call
              if(user)
                values = user.send(restrictor[:name].to_sym).find(:all, :order => restrictor[:value])
              else
                values = restrictor[:views][:user_values_only].send(restrictor[:name].to_sym).find(:all, :order => restrictor[:views][:value])
              end
            end
          end
          @_restrictor_inflector_helper ||= Class.send(:include, ActiveSupport::Inflector).new
          values = restrictor[:class].find(:all, :order => restrictor[:views][:value]) unless values
          if(defined?(Formtastic) && form.is_a?(Formtastic::FormBuilder))
            form.inputs(
              restrictor[:name], 
              :as => :select, 
              :collection => ActiveSupport::OrderdHash[
                *restrictor[:class].all.order(restrictor[:views][:value]).all.map{|r|
                  [r.send(restrictor[:views][:value]), r.id]
                }.flatten
              ]
            )
          else
            [
              form.label(restrictor[:name]),
              form.collection_select(
                "#{@_restrictor_inflector_helper.singularize(restrictor[:name])}_ids",
                values,
                restrictor[:views][:id],
                restrictor[:views][:value],
                {
                  :include_blank => restrictor[:views][:include_blank],
                  :selected => Array(obj.send(restrictor[:name])).map(&restrictor[:views][:id].to_sym)
                },
                :multiple => restrictor[:views][:multiple]
              )
            ]
          end
        end
      else
        []
      end
    end
  end
end

ActionView::Base.send :include, ActiveRestrictors::View
