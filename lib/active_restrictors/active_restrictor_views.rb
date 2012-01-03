module ActiveRestrictors
  module View
    # obj:: Instance with restrictors enabled
    # val_join:: String to join restictor values together
    # Provides array of enabled restrictors in the form of:
    # [[restrictor_name_label, string_of_restriction_values]]
    def display_full_restrictors(obj, val_join = '<br />')
      if(obj.class.respond_to?(:full_restrictors))
        obj.class.full_restrictors.map do |restrictor|
          [
            label(obj.class.name.camelize, restrictor[:name]),
            obj.send(restrictor[:name]).map(&restrictor[:value].to_sym).join(val_join).html_safe
          ]
        end
      else
        []
      end
    end

    def display_custom_restrictors(klass)
      # Stub for now
      []
    end

    # obj:: Instance with restrictors enabled
    # form:: Form object to attach restrictor fields to
    # Provides form items for restrictors in an array of format:
    # [[restrictor_name_label, form_selection_string]]
    def edit_full_restrictors(obj, form)
      if(obj.class.respond_to?(:full_restrictors))
        obj.class.full_restrictors.map do |restrictor|
          if(restrictor[:user_values_only])
            if(restrictor[:user_values_only].respond_to?(:call))
              user = restrictor[:user_values_only].call
              if(user)
                values = user.send(restrictor[:name].to_sym).find(:all, :order => restrictor[:value])
              else
                values = restrictor[:user_values_only].send(restrictor[:name].to_sym).find(:all, :order => restrictor[:value])
              end
            end
          end
          values = restrictor[:class].find(:all, :order => restrictor[:value]) unless values
          [
            form.label(restrictor[:name]),
            form.collection_select(
              restrictor[:name],
              values,
              restrictor[:id],
              restrictor[:value],
              {
                :include_blank => restrictor[:include_blank],
                :selected => Array(obj.send(restrictor[:name])).map(&restrictor[:id].to_sym)
              },
              :multiple => restrictor[:multiple]
            )
          ]
        end
      else
        []
      end
    end

    def edit_custom_restrictors(klass)
      # Stub for now
      []
    end
  end
end

ActionView::Base.send :include, ActiveRestrictors::View
