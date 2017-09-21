module GraphQL
  module Directives
    #
    # The @skip(if: ...) directive
    #
    class SkipDirective
      include GraphQL::Directive
      getter :name
      @name = "skip"

      def call(_field_definition, _selections, _resolved, _context)
        if args.try &.["if"]
          {nil, [] of Error}
        else
          call_next(_field_definition, _selections, _resolved, _context)
        end
      end
    end
  end
end
