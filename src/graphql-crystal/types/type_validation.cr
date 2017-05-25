module GraphQL
  class TypeValidation
    @enum_values_cache = Hash(String, Array(String)?).new { |hash, key| hash[key] = nil }

    def initialize(@types : Hash(String, GraphQL::Language::TypeDefinition)); end

    def accepts?(type_definition, value)

      # Nillable by default ..
      if value == nil && !type_definition.is_a?(GraphQL::Language::NonNullType)
        return true
      end

      case type_definition
      when GraphQL::Language::EnumTypeDefinition
        if value.is_a?(GraphQL::Language::AEnum)
          @enum_values_cache[type_definition.name] ||= type_definition.fvalues.map(
            &.as(GraphQL::Language::EnumValueDefinition).name )
          @enum_values_cache[type_definition.name].not_nil!.includes? value.name
        else
          false
        end
      when GraphQL::Language::UnionTypeDefinition
        true
      when GraphQL::Language::NonNullType
        value ? accepts?(type_definition.of_type, value) : false
      when GraphQL::Language::ListType
        if value.is_a?(Array)
          value.map{ |v| accepts?(type_definition.of_type, v).as(Bool) }.all? { |r| !!r }
        else
          false
        end
      when GraphQL::Language::ScalarTypeDefinition
        case type_definition.name
        when "ID", "Int"
          value.is_a?(Int32)
        when "Float"
          value.is_a?(Float64)
        when "String"
          value.is_a?(String)
        when "Boolean"
          value.is_a?(Bool)
        else
          false
        end
      when GraphQL::Language::ObjectTypeDefinition
        true
      when GraphQL::Language::InputObjectTypeDefinition
        true
      when GraphQL::Language::InputValueDefinition
        true
      when GraphQL::Language::TypeName
        accepts?(@types[type_definition.name], value)
      else
        true
      end
    end
  end
end
