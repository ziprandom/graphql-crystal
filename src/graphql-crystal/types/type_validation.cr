module GraphQL
  #
  # A TypeValidation is used to validate a given input against a
  # TypeDefinition.
  #
  class TypeValidation
    @enum_values_cache = Hash(String, Array(String)?).new { |hash, key| hash[key] = nil }

    def initialize(@types : Hash(String, Language::TypeDefinition)); end

    #
    # Returns true if `value` corresponds to
    # `type_definition`.
    #
    def accepts?(type_definition : GraphQL::Language::AbstractNode, value) : Bool
      # Nillable by default ..
      if value == nil && !type_definition.is_a?(Language::NonNullType)
        return true
      end

      case type_definition
      when Language::EnumTypeDefinition
        if value.is_a?(Language::AEnum) || value.is_a?(String)
          @enum_values_cache[type_definition.name] ||= type_definition.fvalues.map(&.as(Language::EnumValueDefinition).name)
          value_name = value.is_a?(Language::AEnum) ? value.name : value
          @enum_values_cache[type_definition.name].not_nil!.includes? value_name
        else
          false
        end
      when Language::UnionTypeDefinition
        type_definition.types.any? { |_type| accepts?(_type, value) }
      when Language::NonNullType
        value != nil ? accepts?(type_definition.of_type, value) : false
      when Language::ListType
        if value.is_a?(Array)
          value.map { |v| accepts?(type_definition.of_type, v).as(Bool) }.all? { |r| !!r }
        else
          false
        end
      when Language::ScalarTypeDefinition
        case type_definition.name
        when "ID"
          value.is_a?(Int) || value.is_a?(String)
        when "Int"
          value.is_a?(Int)
        when "Float"
          value.is_a?(Number)
        when "String"
          value.is_a?(String)
        when "Boolean"
          value.is_a?(Bool)
        else
          false
        end
      when Language::InputObjectTypeDefinition
        _value = value.is_a?(Language::InputObject) ? value.to_h : value
        return false unless _value.is_a? Hash
        (type_definition.fields.map(&.name) + _value.keys).uniq.each do |key|
          return false unless field = type_definition.fields.find(&.name.==(key))
          if _value.has_key?(field.name)
            return false unless accepts?(field.type, _value[field.name])
          elsif field.default_value
            return false unless accepts?(field.type, field.default_value)
          else
            return accepts?(field.type, nil)
          end
        end
        return true
      when Language::TypeName
        accepts?(@types[type_definition.name], value)
      else
        false
      end
    end
  end
end
