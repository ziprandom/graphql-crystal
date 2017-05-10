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
        if eklass && eklass.responds_to? :resolve
          GraphQL.cast_to_return eklass.resolve(selections, entity)
        elsif field_type.responds_to? :resolve
          resolved = field_type.resolve(selections, entity)
          resolved
        elsif field_type.is_a?(Array)
          entity.as( Array ).map do |e|
            GraphQL.cast_to_return(
              resolve_selections_for_field(
                field_type.first,
                e, selections
              ).as( GraphQL::ObjectType::Resolvable::ReturnType )
            )
          end
        end.as(GraphQL::ObjectType::Resolvable::ReturnType)
      end
    end
  end
end
