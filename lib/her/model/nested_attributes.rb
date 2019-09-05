module Her
  module Model
    module NestedAttributes
      extend ActiveSupport::Concern

      def saved_nested_attributes
        nested_attributes = self.class.saved_nested_associations.each_with_object({}) do |association_name, hash|
          if associate = self.send(association_name)
            Rails.logger.warn "⚠️ saving nested #{association_name}: #{associate}"
            if associate.kind_of?(Array)
              associates = {}
              associate.each_with_index {|a, i|
                associates[i] = to_params_for_nesting(a)
              }
              hash["#{association_name}_attributes".to_sym] = associates
            else
              hash["#{association_name}_attributes".to_sym] = to_params_for_nesting(associate)
            end
          end
        end
      end

      def to_params_for_nesting(associate)
        if associate
          associate_params = associate.to_params
          associate_params = associate_params[associate.class.included_root_element] if associate.class.include_root_in_json?
          associate_params['_destroy'] = associate.destroying?
          associate_params['id'] = associate.id
          associate_params
        end
      end


      module ClassMethods
        # Allow nested attributes for an association
        #
        # @example
        #   class User
        #     include Her::Model
        #
        #     has_one :role
        #     accepts_nested_attributes_for :role
        #   end
        #
        #   class Role
        #     include Her::Model
        #   end
        #
        #   user = User.new(name: "Tobias", role_attributes: { title: "moderator" })
        #   user.role # => #<Role title="moderator">
        def accepts_nested_attributes_for(*associations)
          allowed_association_names = association_names

          associations.each do |association_name|
            unless allowed_association_names.include?(association_name)
              raise Her::Errors::AssociationUnknownError, "Unknown association name :#{association_name}"
            end

            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              if method_defined?(:#{association_name}_attributes=)
                remove_method(:#{association_name}_attributes=)
              end

              def #{association_name}_attributes=(attributes)
                self.#{association_name}.assign_nested_attributes(attributes)
              end
            RUBY
          end
        end

        def saved_nested_associations
          @_her_saved_associations ||= []
        end

        def sends_nested_attributes_for(*associations)
          allowed_association_names = association_names
          associations.each do |association_name|
            unless allowed_association_names.include?(association_name)
              raise Her::Errors::AssociationUnknownError.new("Unknown association name :#{association_name} in sends_nested_attributes_for")
            end
            saved_nested_associations.push association_name
          end
        end
      end
    end
  end
end
