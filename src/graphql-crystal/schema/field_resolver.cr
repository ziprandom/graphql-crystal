module GraphQL
  module Schema
    module FieldResolver
      #
      # Recursively Resolve fields and selections to Response Objects
      #
      def self.resolve_selections_for_field(field_type, entity, selections)

        if entity.responds_to? :class
          eklass = entity.class
        end

        if ( (eklass && eklass.responds_to? :resolve) && ( res = eklass.resolve(selections, entity) ) ) ||
           ( (field_type.responds_to? :resolve) && ( res = field_type.resolve(selections, entity) ) )
          if res.is_a?(Tuple)
            result, errors = res
          else
            result = res
            errors = Array(GraphQL::ObjectType::Resolvable::Error).new
          end
        elsif field_type.is_a?(Array)
          result = Array(GraphQL::Schema::ReturnType).new
          errors = Array(GraphQL::ObjectType::Resolvable::Error).new
          entity.as( Array ).each_with_index do |e, index|
            res, errs = resolve_selections_for_field(
                   field_type.first,
                   e, selections
                 )
            result << GraphQL.cast_to_return(res)
            errors += errs.map do |e|
              GraphQL::ObjectType::Resolvable::Error.new(message: e[:message], path: [index] + e[:path] )
            end
          end
        end
        {
          GraphQL.cast_to_return(result),
          errors.not_nil!
        }
      end
    end
  end
end
