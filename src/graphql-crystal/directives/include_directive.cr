module GraphQL
  module Directives
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

module GraphQL
  module Directives
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
