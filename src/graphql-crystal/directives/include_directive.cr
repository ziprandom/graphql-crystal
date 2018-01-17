module GraphQL
  module Directives
    #
    # The @include(if: ...) directive
    #
    class IncludeDirective
      include GraphQL::Directive
      getter :name
      @name = "include"

      def call(_field_definition, _selections, _resolved, _context)
        if args.try &.["if"]
          call_next(_field_definition, _selections, _resolved, _context)
        else
          {nil, [] of Error}
        end
      end
    end
  end
end
