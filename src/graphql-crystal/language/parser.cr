require "./type"
require "cltk/parser"
require "./lexer"
require "./nodes"

module GraphQL
  module Language
    #
    # A CLTK Parser for the GraphQL Language
    #
    class Parser < CLTK::Parser
      production(:document) do
        clause("definition+") { |definitions| Document.new(definitions: definitions) }
      end

      production(:definition) do
        clause("comments definition") do |comment, definition|
          if definition.responds_to?(:"description=") && !definition.description
            definition.description = comment.as(String)
          end
          definition
        end

        clause(:operation_definition)
        clause(:fragment_definition)
        clause(:type_system_definition)
      end

      production(:operation_definition) do
        clause("operation_type name? variable_definitions? \
                  directive* selection_set") do |operation_type, name, variables, directives, selections|
          OperationDefinition.new(operation_type: operation_type,
            name: name, variables: variables || [] of VariableDefinition,
            directives: directives, selections: selections)
        end

        clause("selection_set") do |selections|
          OperationDefinition.new(name: "",
            variables: Array(VariableDefinition).new,
            directives: Array(Directive).new,
            operation_type: "query",
            selections: selections)
        end
      end

      production(:operation_type) do
        clause(:QUERY) { |t| "query" }
        clause(:MUTATION) { |t| "mutation" }
        clause(:SUBSCRIPTION) { |t| "subscription" }
      end

      production(:variable_definitions) do
        clause("LPAREN .variable_definition+ RPAREN") { |list| list }
      end

      production(:variable_definition) do
        clause("VAR_SIGN .name COLON .type") do |name, type|
          VariableDefinition.new(
            name: name, type: type,
            default_value: nil
          )
        end

        clause("VAR_SIGN .name COLON .type .default_value") do |name, type, default_value|
          VariableDefinition.new(
            name: name, type: type,
            default_value: default_value
          )
        end
      end

      production(:type) do
        clause(:name) { |name| TypeName.new(name: name) }
        clause(".type BANG") { |type| NonNullType.new(of_type: type) }
        clause("LBRACKET .type RBRACKET") { |type| ListType.new(of_type: type) }
      end

      production(:default_value) do
        clause("EQUALS .input_value") do |val|
          case val
          when Nil
            val.as(Nil).to_json
          else
            val
          end
        end
      end

      production(:selection_set) do
        clause("LCURLY .selection* RCURLY") { |list| list }
      end

      production(:selection) do
        clause(:field)
        clause(:fragment_spread)
        clause(:inline_fragment)
      end

      production(:field) do
        clause(
          "name_without_on arguments? directive* selection_set?"
        ) do |name, arguments, directives, selections|
          field = Field.new(
            name: name,
            _alias: nil,
            arguments: arguments || [] of Argument,
            directives: directives || [] of Directive,
            selections: selections || [] of Selection
          )
          field
        end

        clause(
          ".name_without_on COLON .name .arguments? .directive*? .selection_set?"
        ) do |_alias, name, arguments, directives, selections|
          Field.new(
            name: name,
            _alias: _alias,
            arguments: arguments || [] of Argument,
            directives: directives || [] of Directive,
            selections: selections || [] of Selection
          )
        end
      end

      production(:schema_keyword) do
        clause(:SCHEMA) { "schema" }
        clause(:SCALAR) { "scalar" }
        clause(:TYPE) { "type" }
        clause(:IMPLEMENTS) { "implements" }
        clause(:INTERFACE) { "interface" }
        clause(:UNION) { "union" }
        clause(:ENUM) { "enum" }
        clause(:INPUT) { "input" }
        clause(:DIRECTIVE) { "directive" }
      end

      production(:name) do
        clause(:name_without_on)
        clause(:ON)
      end

      production(:name_without_on) do
        clause(:IDENTIFIER)
        clause(:FRAGMENT)
        clause(:TRUE)
        clause(:FALSE)
        clause(:operation_type)
        clause(:schema_keyword)
      end

      production(:enum_name) do
        clause(:IDENTIFIER)
        clause(:FRAGMENT)
        clause(:ON)
        clause(:operation_type)
        clause(:schema_keyword)
      end

      production(:enum_value_definition) do

        clause("comments enum_value_definition") do |comment, definition|
          definition.as(EnumValueDefinition).tap { |d| d.description = comment.as(String) }
        end

        clause("enum_name directive*") do |name, directives|
          EnumValueDefinition.new(name: name, directives: directives, selection: nil, description: nil)
        end
      end

      production(:arguments) do
        clause("LPAREN .argument* RPAREN") { |list| list }
      end

      production(:argument) do
        clause(".name COLON .input_value") do |name, value|
          Argument.new(
            name: name,
            value: Language.to_argumentvalue(value)
          )
        end
      end

      production(:input_value) do
        clause(:FLOAT) { |t| t.as(String).to_f64 }
        clause(:INT) { |t| t.as(String).to_i32 }
        clause(:STRING) { |t| t.as(String) }
        clause(:TRUE) { |t| true }
        clause(:FALSE) { |t| false }
        clause(:null_value)
        clause(:variable)
        clause(:list_value)
        clause(:object_value)
        clause(:enum_value)
      end

      production(:null_value) do
        clause(:NULL) { |t| NullValue.new(name: t || "") }
      end

      production(:variable) do
        clause("VAR_SIGN .name") { |name| VariableIdentifier.new(name: name) }
      end

      production(:list_value) do
        clause("LBRACKET .input_value* RBRACKET") { |list| list }
      end

      production(:object_value) do
        clause("LCURLY .object_value_field* RCURLY") do |list|
          InputObject.new(arguments: list)
        end
      end

      production(:object_value_field) do
        clause(".name COLON .input_value") do |name, value|
          Argument.new(name: name, value: Language.to_argumentvalue(value))
        end
      end

      production(:enum_value) do
        clause(:enum_name) { |name| AEnum.new(name: name) }
      end

      production(:directive) do
        clause("DIR_SIGN .name .arguments?") do |name, arguments|
          Directive.new(name: name, arguments: arguments || Array(Argument).new)
        end
      end

      production(:fragment_spread) do
        clause("ELLIPSIS .name_without_on .directive*") do |name, directives|
          FragmentSpread.new(name: name, directives: directives)
        end
      end

      production(:inline_fragment) do
        clause(
          "ELLIPSIS ON .type .directive* .selection_set") do |type, directives, selections|
          InlineFragment.new(type: type, directives: directives, selections: selections)
        end
        clause("ELLIPSIS .directive* .selection_set") do |directives, selections|
          InlineFragment.new(type: nil, directives: directives, selections: selections)
        end
      end

      production(:fragment_definition) do
        clause(
          "FRAGMENT .name_without_on? ON .type .directive* .selection_set") do |name, type, directives, selections|
          FragmentDefinition.new(name: name, type: type, directives: directives, selections: selections)
        end
      end

      production(:type_system_definition) do
        clause(:schema_definition)
        clause(:type_definition)
        clause(:directive_definition)
      end

      production(:schema_definition) do
        clause(
          "SCHEMA LCURLY .operation_type_definition_list RCURLY") do |definitions|
          definitions = definitions.as(Array).reduce(Hash(String, String).new) do |memo, pair|
            pair.as(Tuple(String, String)).tap { |pair| memo[pair[0]] = pair[1] }
            memo
          end
          SchemaDefinition.new(
            query: definitions["query"]?,
            mutation: definitions["mutation"]?,
            subscription: definitions["subscription"]?
          )
        end
      end

      nonempty_list(:operation_type_definition_list, :operation_type_definition)

      production(:operation_type_definition) do
        clause(".operation_type COLON .name") do |type, name|
          {type.as(String), name.as(String)}
        end
      end

      production(:type_definition) do
        clause(:scalar_type_definition)
        clause(:object_type_definition)
        clause(:interface_type_definition)
        clause(:union_type_definition)
        clause(:enum_type_definition)
        clause(:input_object_type_definition)
      end

      production(:scalar_type_definition) do
        clause("SCALAR .name .directive*") do |name, directives|
          ScalarTypeDefinition.new(name: name, directives: directives, description: nil)
        end
      end

      production(:object_type_definition) do
        clause(
          "TYPE .name .implements? .directive* LCURLY .field_definition* RCURLY"
        ) do |name, interfaces, directives, fields|
          ObjectTypeDefinition.new(name: name,
            interfaces: interfaces || [] of String,
            directives: directives,
            fields: fields,
            description: nil)
        end
      end

      production(:implements) do
        clause("IMPLEMENTS .name+") { |name| name }
      end

      production(:input_value_definition) do

        clause("comments input_value_definition") do |comment, definition|
          definition.as(InputValueDefinition).tap { |d| d.description = comment.as(String) }
        end

        clause(
          ".name COLON .type .default_value? .directive*") do |name, type, default_value, directives|
          InputValueDefinition.new(
            name: name, type: type, default_value: Language.to_fvalue(default_value),
            directives: directives, description: nil)
        end
      end

      production(:arguments_definitions) do
        clause("LPAREN .input_value_definition+ RPAREN") { |list| list }
      end

      production(:field_definition) do

        clause("comments field_definition") do |comment, definition|
          definition.as(FieldDefinition).tap { |d| d.description = comment.as(String) }
        end

        clause(
          ".name .arguments_definitions? COLON .type .directive*") do |name, arguments, type, directives|
          FieldDefinition.new(name: name, arguments: arguments || [] of Argument,
            type: type, directives: directives, description: nil)
        end
      end

      production(:interface_type_definition) do
        clause(
          "INTERFACE .name .directive* LCURLY .field_definition* RCURLY") do |name, directives, fields|
          InterfaceTypeDefinition.new(name: name, fields: fields, directives: directives, description: nil)
        end
      end

      build_nonempty_list_production(
        :union_members,
        :name,
        :PIPE
      )

      production(:union_type_definition) do
        clause("UNION .name .directive* EQUALS .union_members") do |name, directives, members|
          UnionTypeDefinition.new(name: name,
            types: members.as(Array).map { |name| TypeName.new(name: name) }.as(Array(TypeName)),
            directives: directives, description: nil)
        end
      end

      production(:enum_type_definition) do
        clause("ENUM .name .directive* LCURLY .enum_value_definition+ RCURLY") do |name, directives, values|
          EnumTypeDefinition.new(name: name, fvalues: values.as(Array), directives: directives, description: nil)
        end
      end

      production(:input_object_type_definition) do
        clause(
          "INPUT .name .directive* LCURLY .input_value_definition+ RCURLY") do |name, directives, values|
          InputObjectTypeDefinition.new(name: name, fields: values, directives: directives, description: nil)
        end
      end

      production(:directive_definition) do
        clause(
          "DIRECTIVE DIR_SIGN .name .arguments_definitions? ON .directive_locations"
        ) do |name, arguments, locations|
          DirectiveDefinition.new(name: name, arguments: arguments, locations: locations, description: nil)
        end
      end

      production(:comments) do
        clause(:COMMENT)
      end

      build_nonempty_list_production(:directive_locations, :name, :PIPE)

      finalize(use: "./parser.bin")
    end
  end
end
