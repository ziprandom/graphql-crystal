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
        if value.is_a?(Language::AEnum)
          @enum_values_cache[type_definition.name] ||= type_definition.fvalues.map(&.as(Language::EnumValueDefinition).name)
          @enum_values_cache[type_definition.name].not_nil!.includes? value.name
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
        when "Time"
          value.is_a?(Time)
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
        return false unless value.is_a? Hash
        (type_definition.fields.map(&.name) + value.keys).uniq.each do |key|
          return false unless field = type_definition.fields.find(&.name.==(key))
          if value.has_key?(field.name)
            vv = value[field.name]
            {% if JSON::NEW_JSON_ANY_TYPE %}
            vv = vv.is_a?(JSON::Any) ? vv.as(JSON::Any).raw : vv
            {% end %}
            return false unless accepts?(field.type, vv)
          elsif field.default_value
            return false unless accepts?(field.type, field.default_value)
          else
            return false
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
