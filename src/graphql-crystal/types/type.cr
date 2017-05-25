module GraphQL

    alias Error = {message: String, path: Array(String|Int32) }

    class FieldDefinition
      def resolve_arguments(field)
        field.arguments.reduce(
          Hash(String, GraphQL::Schema::ReturnType).new
        ) do |args, arg|
          args[arg.name] = arg.value.as(GraphQL::Schema::ReturnType)
          args
        end
      end
    end
    class InputObjectTypeDefinition
      def accepts?(field : GraphQL::Language::Argument)
        return [] of Error
      end
    end
    class InputValueDefinition
      def accepts?(field : GraphQL::Language::Argument)
        return [] of Error
      end
    end

end
