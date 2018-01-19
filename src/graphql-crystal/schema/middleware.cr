module GraphQL
  module Schema
    module Middleware
      property next : Middleware | Proc | Nil

      abstract def call(
        node : GraphQL::Language::TypeDefinition | GraphQL::Language::FieldDefinition,
        selection : Array(Language::Selection),
        object : ResolveCBReturnType, context : Context
      )

      private def call_next(*args)
        next_handler = @next
        if next_handler
          next_handler.call(args[0], args[1], args[2].as(ResolveCBReturnType), args[3])
        else
          raise "incomplete middleware chain"
        end
      end

      alias Proc = Language::AbstractNode, Array(Language::AbstractNode), ResolveCBReturnType, Context -> {ReturnType, Array(GraphQL::Error)}
    end
  end
end
