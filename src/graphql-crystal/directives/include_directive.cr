module GraphQL
  module Directives
    class IncludeDirective
      include GraphQL::Directive
      getter :name
      @name = "include"

      def call(*args)
        pp "i am running!"
        call_next(*args)
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

      def call(*args)
        call_next(*args)
      end
    end
  end
end
