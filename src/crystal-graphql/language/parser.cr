require "cltk/parser"
require "./nodes"
module GraphQl
  module Language
    class Parser < CLTK::Parser

      production(:target) do
        clause(:document) { |d| d }
      end

      production(:document) do
        clause(:definitions_list) { |definitions| Document.new(definitions: definitions) }
      end

      build_nonempty_list_production(
        :definitions_list,
        :definition
      )

      production(:definition) do
        clause(:operation_definition)   { |e| e }
        clause(:fragment_definition)    { |e| e }
        clause(:type_system_definition) { |e| e }
      end

      production(:operation_definition) do

        clause("operation_type operation_name? variable_definitions? \
                  directives_list_opt selection_set") do |operation_type, name, variables, directives, selections|
          OperationDefinition.new(operation_type: operation_type,
                                   name: name, variables: variables,
                                   directives: directives, selections: selections)
        end

        clause("selection_set") do |selections|
          OperationDefinition.new(name: "", variables: Array(Type).new(), directives: Array(Type).new(), operation_type: "query", selections: selections)
        end
      end

      production(:operation_type) do
        clause(:QUERY) { |t| t }
        clause(:MUTATION) { |t| t }
        clause(:SUBSCRIPTION) { |t| t }
      end

      production(:operation_name) do
        clause(:name) { |t| t }
      end

      production(:variable_definitions) do
        clause("LPAREN variable_definitions_list RPAREN") { |_, list, _| list }
      end

      build_nonempty_list_production(
        :variable_definitions_list,
        :variable_definition
      )

      production(:variable_definition) do
        clause("VAR_SIGN name COLON type default_value?") do |t1, name, _, type, default_value| nil
          VariableDefinition.new(
            name: name, type: type,
            default_value: default_value
          )
        end
      end

      production(:type) do
        clause(:name) { |name| TypeName.new(name: name) }
        clause("type BANG") { |type| NonNullType.new(of_type: type) }
        clause("LBRACKET type RBRACKET") { |_, type, _| ListType.new(of_type: type) }
      end

      production(:default_value) do
        clause("EQUALS input_value") { |_, val| val }
      end

      production(:selection_set) do
        clause("LCURLY RCURLY") { Array(Selection).new }
        clause("LCURLY selection_list RCURLY") { |_, list, _| list }
      end

      build_list_production(:selection_list, :selection)

      production(:selection) do
        clause(:field) { |e| e }
        clause(:fragment_spread) { |e| e }
        clause(:inline_fragment) { |e| e }
      end

      production(:field) do
        clause("name arguments? directives_list? selection_set?") do |name, arguments, directives, selections| nil
          Field.new(
            name: name,
            alias: nil,
            arguments: arguments || [] of Argument,
            directives: directives || [] of Directive,
            selections: selections || [] of Selection
          )
        end

        clause(
          "name COLON name arguments? directives_list_opt? selection_set?"
        ) do |_alias, _, name, arguments, directives, selections|
          Field.new(
            name: name,
            alias: _alias,
            arguments: arguments || [] of Argument,
            directives: directives || [] of Directive,
            selections: selections || [] of Selection
          )
        end
      end

      production(:schema_keyword) do
        clause(:SCHEMA)      { |t| t }
        clause(:SCALAR)      { |t| t }
        clause(:TYPE)        { |t| t }
        clause(:IMPLEMENTS)  { |t| t }
        clause(:INTERFACE)   { |t| t }
        clause(:UNION)       { |t| t }
        clause(:ENUM)        { |t| t }
        clause(:INPUT)       { |t| t }
        clause(:DIRECTIVE)   { |t| t }
      end

      production(:name) do
        clause(:name_without_on) { |t| t }
        clause(:ON) { |t| t }
      end

      production(:name_without_on) do
        clause(:IDENTIFIER) { |t| t }
        clause(:FRAGMENT) { |t| t }
        clause(:TRUE) { |t| t }
        clause(:FALSE) { |t| t }
        clause(:operation_type) { |t| t }
        clause(:schema_keyword) { |t| t }
      end

      production(:enum_name) do
        clause(:IDENTIFIER) { |t| t }
        clause(:FRAGMENT) { |t| t }
        clause(:ON) { |t| t }
        clause(:operation_type) { |t| t }
        clause(:schema_keyword) { |t| t }
      end

      build_nonempty_list_production(:name_list, :name)

      production(:enum_value_definition) do
        clause("enum_name directives_list_opt") do |name, directives|
          EnumValueDefinition.new(name: name, directives: directives, selection: nil)
        end
      end

      build_nonempty_list_production(
        :enum_value_definitions,
        :enum_value_definition
      )

      production(:arguments) do
        clause("LPAREN RPAREN") { [] of Argument }
        clause("LPAREN arguments_list RPAREN")  { |_, list, _| list }
      end

      build_nonempty_list_production(
        :arguments_list,
        :argument
      )

      production(:argument) do
        clause("name COLON input_value") { |name, _, value| Argument.new(name: name, value: value) }
      end

      production(:input_value) do
        clause(:FLOAT)        { |t| t.as(Float64) }
        clause(:INT)          { |t| t.as(Int32) }
        clause(:STRING)       { |t| t.as(String) }
        clause(:TRUE)         { |t| true }
        clause(:FALSE)        { |t| false }
        clause(:null_value)   { |t| t }
        clause(:variable)     { |t| t }
        clause(:list_value)   { |t| t }
        clause(:object_value) { |t| t }
        clause(:enum_value)   { |t| t }
      end

      production(:null_value) do
        clause(:NULL) { |t| NullValue.new(name: t.as(CLTK::Token).value) }
      end

      production(:variable) do
        clause("VAR_SIGN name") { |_, name| VariableIdentifier.new(name: name) }
      end

      production(:list_value) do
        clause("LBRACKET RBRACKET") { [] of FValue }
        clause("LBRACKET list_value_list RBRACKET") { |_, list, _| list }
      end

      build_nonempty_list_production(
        :list_value_list,
        :input_value
      )

      production(:object_value) do
        clause("LCURLY RCURLY") { InputObject.new(arguments: [] of Argument) }
        clause("LCURLY object_value_list RCURLY") do |_, list, _|
          InputObject.new(arguments: list)
        end
      end

      build_nonempty_list_production(
        :object_value_list,
        :object_value_field
      )

      production(:object_value_field) do
        clause("name COLON input_value") { |name, _, value| Argument.new(name: name, value: value)}
      end

      production(:enum_value) do
        clause(:enum_name) { |name| AEnum.new(name: name) }
      end

      build_list_production(
        :directives_list_opt,
        :directive
      )

      build_nonempty_list_production(
        :directives_list,
        :directive
      )

      production(:directive) do
        clause("DIR_SIGN name arguments") do |_, name, arguments|
          Directive.new(name: name, arguments: arguments)
        end
      end

      production(:fragment_spread) do
        clause("ELLIPSIS name_without_on directives_list_opt") do |_, name, directives|
          FragmentSpread.new(name: name, directives: directives )
        end
      end

      production(:inline_fragment) do
        clause(
          "ELLIPSIS ON type directives_list_opt selection_set"
        ) do |_, _, type, directives, selections|
            InlineFragment.new(type: type, directives: directives, selections: selections)
        end
        clause("ELLIPSIS directives_list_opt selection_set") do |_, directives, selections|
            InlineFragment.new(type: nil, directives: directives, selections: selections)
        end
      end

      production(:fragment_definition) do
        clause(
          "FRAGMENT name_without_on? ON type directives_list_opt selection_set"
        ) do |_, name, _, type, directives, selections|
          FragmentDefinition.new(name: name, type: type, directives: directives, selections: selections)
        end
      end

      production(:type_system_definition) do
        clause(:schema_definition) { |t| t }
        clause(:type_definition) { |t| t }
        clause(:directive_definition) { |t| t }
      end

      production(:schema_definition) do
        clause(
          "SCHEMA LCURLY operation_type_definition_list RCURLY"
        ) do |_, _, definitions|
          definitions = definitions.as(Hash(String, CLTK::Type))
          SchemaDefinition.new(
            query: definitions["query"],
            mutation: definitions["mutation"],
            subscription: definitions["subscription"]
          )
        end
      end

      production(:operation_type_definition_list) do
        clause(:operation_type_definition) { |t| t}
        clause(
          "operation_type_definition_list operation_type_definition"
        ) do |list, definition|
          list.as(Hash(String, CLTK::Type)).merge(
            definition.as(Hash(String, CLTK::Type))
          )
        end
      end

      production(:operation_type_definition) do
        clause("operation_type COLON name") do |type, _, name|
          ({type.as(String) => name.as(CLTK::Type)}).as(CLTK::Type)
        end
      end

      production(:type_definition) do
        clause(:scalar_type_definition) { |t| t }
        clause(:object_type_definition) { |t| t }
        clause(:interface_type_definition) { |t| t }
        clause(:union_type_definition) { |t| t }
        clause(:enum_type_definition) { |t| t }
        clause(:input_object_type_definition) { |t| t }
      end

      production(:scalar_type_definition) do
        clause("SCALAR name directives_list_opt") do |_, name, directives|
          ScalarTypeDefinition.new(name: name, directives: directives, description: "")
        end
      end

      production(:object_type_definition) do
        clause(
          "TYPE name implements? directives_list_opt LCURLY field_definition_list RCURLY"
        ) do | _, name, interfaces, directives, _, fields|
          ObjectTypeDefinition.new(name: name,
                                    interfaces: interfaces,
                                    directives: directives,
                                    fields: fields,
                                    description: "")
        end
      end

      production(:implements) do
        clause("IMPLEMENTS name_list") { | _, name| name }
      end

      production(:input_value_definition) do
        clause(
          "name COLON type default_value? directives_list_opt"
        ) do |name, _, type, default_value, directives |
          InputValueDefinition.new(name: name, type: type, default_value: default_value, directives: directives)
        end
      end

      build_nonempty_list_production(
        :input_value_definition_list,
        :input_value_definition
      )

      production(:arguments_definitions) do
        clause("LPAREN input_value_definition_list RPAREN") { |_, list, _| list }
      end

      production(:field_definition) do
        clause(
          "name arguments_definitions? COLON type directives_list_opt"
        ) do |name, arguments, _, type, directives|
          FieldDefinition.new(name: name, arguments: arguments,
                               type: type, directives: directives, description: "")
        end
      end

      build_list_production(
        :field_definition_list,
        :field_definition
      )

      production(:interface_type_definition) do
        clause(
          "INTERFACE name directives_list_opt LCURLY field_definition_list RCURLY"
        ) do | _, name, directives, _, fields |
          InterfaceTypeDefinition.new(name: name, fields: fields, directives: directives, description: "")
        end
      end

      production(:union_members) do
        clause(:name) {|name| [TypeName.new(name: name)] }
        clause("union_members PIPE name") {|members, _, name| members.as(Array) << TypeName.new(name: name)}
      end

      production(:union_type_definition) do
        clause("UNION name directives_list_opt EQUALS union_members") do |_, name, directives, _,members|
          UnionTypeDefinition.new(name: name, types: members, directives: directives, description: "")
        end
      end

      production(:enum_type_definition) do
        clause("ENUM name directives_list_opt LCURLY enum_value_definitions RCURLY") do |_, name, directives, _,values|
          EnumTypeDefinition.new(name: name, fvalues: values, directives: directives, description: "")
        end
      end

      production(:input_object_type_definition) do
        clause(
          "INPUT name directives_list_opt LCURLY input_value_definition_list RCURLY"
        ) do |_, name, directives, _, values|
          InputObjectTypeDefinition.new(name: name, fields: values, directives: directives, description: "")
        end
      end

      production(:directive_definition) do
        clause (
          "DIRECTIVE DIR_SIGN name arguments_definitions? ON directive_locations"
        ) do |_, _, name, arguments, _, locations|
          DirectiveDefinition.new(name: name, arguments: arguments, locations: locations, description: "")
        end
      end

      build_nonempty_list_production(:directive_locations, :name, :PIPE)

      finalize({ explain: false, precedence: false, lookahead: false })
    end
  end
end
