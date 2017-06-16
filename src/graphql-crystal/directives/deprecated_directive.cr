require "./directive"
module GraphQL
  module Directives
    module IsDeprecated
      macro included
        @deprecated : Bool?
        @deprecation_reason : String?

        def _graphql_deprecated
          @deprecated ||= directives.any? &.name.==("deprecated")
        end

        def _graphql_deprecation_reason(schema)
          @deprecation_reason ||= (
            if dir = directives.find(&.name.==("deprecated"))
              dir.arguments.find(&.name = "reason").try(&.value) ||
                schema.directive_definitions["deprecated"]
                .arguments.find(&.name.==("reason")).try &.default_value
            else
              nil
            end.as(String?)
          )
        end

        field :isDeprecated do
          _graphql_deprecated
        end

        field :deprecationReason do
          _graphql_deprecation_reason(schema)
        end
      end
    end

  end
end
