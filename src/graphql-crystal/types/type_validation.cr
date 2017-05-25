module GraphQL
  class TypeValidation
    def initialize(@types : Hash(String, GraphQL::Language::TypeDefinition)); end

    def accepts?(type_definition, value)
      case type_definition
      when GraphQL::Language::EnumTypeDefinition
        pp type_definition
        true
      when GraphQL::Language::UnionTypeDefinition
        pp type_definition
        true
      when GraphQL::Language::NonNullType
        value ? accepts?(type_definition.of_type, value) : false
      when GraphQL::Language::ListType
        pp type_definition
        true
      when GraphQL::Language::ScalarTypeDefinition
        pp type_definition
        true
      when GraphQL::Language::ObjectTypeDefinition
        pp type_definition
        true
      when GraphQL::Language::InputObjectTypeDefinition
        pp type_definition
        true
      when GraphQL::Language::InputValueDefinition
        pp type_definition
        true
      else
        true
      end
    end
  end
end
