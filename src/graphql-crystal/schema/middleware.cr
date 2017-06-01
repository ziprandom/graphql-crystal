module GraphQL
  module Schema
    module Middleware
      property next : Middleware | Proc | Nil

      abstract def call(
                     node : GraphQL::Language::TypeDefinition|GraphQL::Language::FieldDefinition,
                     selection : Language::Selection | Array(Language::Selection),
                     object : ResolveCBReturnType, context : Context)

        def call_next(node : GraphQL::Language::AbstractNode,
                      selection : Language::Selection | Array(Language::Selection),
                      object : ResolveCBReturnType, context : Context)

          if next_handler = @next.not_nil!
            next_handler.call(node, selection, object.as(ResolveCBReturnType), context)
          else
            raise "incomplete middleware chain"
          end
        end

        alias Proc = GraphQL::Language::TypeDefinition|GraphQL::Language::FieldDefinition,
              Language::Selection | Array(Language::Selection),
              ResolveCBReturnType, Context -> {ReturnType, Array(Error)}
      end

  end
end
