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
  alias Error = {message: String, path: Array(String | Int32)}

  module Schema
    # Instantiate the `Schema` class from a
    # String that represents a graphql-schema in
    # the graphql schema definition language
    def self.from_schema(schema_string)
      Schema.new GraphQL::Language.parse(schema_string)
    end

    # a struct that can be inherited from
    # when defining custom InputType structs
    # for conveniently accessing query parameters
    abstract struct InputType
      macro inherited
        def_clone
      end
      # abstract def self.from_json(json) : InputType
    end

    struct AlibiType < InputType
      JSON.mapping({some: Bool})
    end
  end

  private alias ReturnType = String | Int32 | Int64 | Float64 | Bool | Nil | Array(ReturnType) | Hash(String, ReturnType) |
                             Schema::InputType
  private alias ResolveCBReturnType = ReturnType | ObjectType | Nil | Array(ResolveCBReturnType)
end
