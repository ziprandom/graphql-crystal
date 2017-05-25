module GraphQL
  module Schema
    module Validation

      def self.validate_params_against_query_definition(query : Language::OperationDefinition, params = nil)
        # validate all the obligatory variables have been defined
        params ||= Hash(String, Nil).new
        new_params = params.dup.clear
        all_errors = Hash(String, Array(String)).new
        query.variables.as(Array(Language::VariableDefinition)).each do |variable|
          # param given with query
          if (param = params[variable.name]?)
            errors = field_definition_rejects_value?(variable.type.as(Language::Type), param)
            # param given with query doesn't have the right type => add to errors
            if errors
              all_errors[variable.name] = errors.not_nil!
            # param given with query has the right type => nice, add to params
            else
              new_params = new_params.merge({variable.name => param})
              next
            end
          # param not given with query but field can be null => set to nil
          elsif !variable.type.is_a?(Language::NonNullType)
            new_params = new_params.merge({variable.name => nil})
          # param not given with query but has a default value => use it
          elsif variable.default_value
            new_params = new_params.merge({variable.name => variable.default_value})
          end
        end
        # TODO use Exceptions here, this is not go!
        { new_params, all_errors }
      end
    end
  end
end
