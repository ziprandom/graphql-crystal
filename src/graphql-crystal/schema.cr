require "./language"
require "./types/type_validation"
require "./types/object_type"
require "./schema/schema"
require "./schema/*"
# require "./schema/schema_execute"
# require "./schema/validation"
# require "./schema/variable_resolver.cr"
# require "./schema/fragment_resolver"
module GraphQL

  # Record the message and path of a resolution error
  alias Error = {message: String, path: Array(String|Int32) }

  module Schema
    # Instantiate the `Schema` class from a
    # String that represents a graphql-schema in
    # the graphql schema definition language
    def self.from_schema(schema_string)
      Schema.new GraphQL::Language.parse(schema_string)
    end

    abstract struct InputType
      macro inherited
        def_clone
      end
      #abstract def self.from_json(json) : InputType
    end
    struct AlibiType < InputType
      JSON.mapping({some: Bool})
    end
  end


  module Schema

    alias ReturnType = String | Int32 | Int64 | Float64 | Bool | Nil | Array(ReturnType) | Hash(String, ReturnType) |
                       InputType
    alias ResolveCBReturnType = ReturnType | ObjectType | Nil | Array(ResolveCBReturnType)

    def self.substitute_argument_variables(query : GraphQL::Language::OperationDefinition, params)
      full_params, errors = GraphQL::Schema::Validation.validate_params_against_query_definition(query, params);
      raise "provided params had errors #{errors}" if errors.any?
      GraphQL::Schema::VariableResolver.visit(query, full_params)
    end

    def self.cast_to_return(value)
      case value
      when Hash
        value.reduce(Hash(String, ReturnType).new) do |memo, h|
          memo[h[0]] = cast_to_return(h[1]).as(ReturnType)
          memo
        end
      when Array
        value.map { |v| cast_to_return(v).as(ReturnType) }
      when GraphQL::Language::AEnum
        value.name
      else
        value
      end.as(ReturnType)
    end

  end
end
