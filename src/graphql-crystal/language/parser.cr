require "./type"
require "cltk/parser"
require "./lexer"
require "./nodes"

module GraphQL
  module Language
    class Parser < CLTK::Parser

      production(:document) do
        clause(:definitions_list) { |definitions| Document.new(definitions: definitions) }
      end

      build_nonempty_list_production(
        :definitions_list,
        :definition
      )

      production(:definition) do
        clause(:operation_definition)
        clause(:fragment_definition)
        clause(:type_system_definition)
      end

      production(:operation_definition) do

        clause("operation_type operation_name? variable_definitions? \
                  directives_list_opt selection_set") do |operation_type, name, variables, directives, selections|
          OperationDefinition.new(operation_type: operation_type,
                                   name: name, variables: variables || [] of VariableDefinition,
                                   directives: directives, selections: selections)
        end

        clause("selection_set") do |selections|
          OperationDefinition.new(name: "",
            variables: Array(Type).new(),
            directives: Array(Type).new(),
            operation_type: "query",
            selections: selections)
        end
      end

      production(:operation_type) do
        clause(:QUERY) { |t| "query" }
        clause(:MUTATION) { |t| "mutation" }
        clause(:SUBSCRIPTION) { |t| "subscription" }
      end

      production(:operation_name) do
        clause(:name)
      end

      production(:variable_definitions) do
        clause("LPAREN variable_definition+ RPAREN") { |_, list, _| list }
      end

      production(:variable_definition) do
        clause("VAR_SIGN name COLON type") do |t1, name, _, type|
          VariableDefinition.new(
            name: name, type: type,
            default_value: nil
          )
        end

        clause("VAR_SIGN name COLON type default_value") do |t1, name, _, type, default_value|
          VariableDefinition.new(
            name: name, type: type,
            default_value: default_value
          )
        end

      end

      production(:type) do
        clause(:name) { |name| TypeName.new(name: name) }
        clause("name BANG") { |name| NonNullType.new(of_type: TypeName.new(name: name)) }
        clause("LBRACKET type RBRACKET") { |_, type, _| ListType.new(of_type: type) }
      end

      production(:default_value) do
        clause("EQUALS input_value") { |_, val| val }
      end

      production(:selection_set) do
        clause("LCURLY RCURLY") { Array(Selection).new }
        clause("LCURLY selection+ RCURLY") { |_, list, _| list }
      end

      production(:selection) do
        clause(:field)
        clause(:fragment_spread)
        clause(:inline_fragment)
      end

      production(:field) do
        clause("name arguments? directives_list? selection_set?") do |name, arguments, directives, selections|
          field = Field.new(
            name: name,
            alias: nil,
            arguments: arguments || [] of Argument,
            directives: directives || [] of Directive,
            selections: selections || [] of Selection
          )
          field
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
        clause(:SCHEMA)     { "schema"     }
        clause(:SCALAR)     { "scalar"     }
        clause(:TYPE)       { "type"       }
        clause(:IMPLEMENTS) { "implements" }
        clause(:INTERFACE)  { "interface"  }
        clause(:UNION)      { "union"      }
        clause(:ENUM)       { "enum"       }
        clause(:INPUT)      { "input"      }
        clause(:DIRECTIVE)  { "directive"  }
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
        clause("name COLON input_value") do |name, _, value|
          cvalue = (
            value.is_a?(Array) ? value.map{|v| v.as(ArgumentValue)} : value
          ).as(ArgumentValue)
          Argument.new(
            name: name,
            value: cvalue
          )
        end
      end

      production(:input_value) do
        clause(:FLOAT)        { |t| t.as(String).to_f64 }
        clause(:INT)          { |t| t.as(String).to_i32 }
        clause(:STRING)       { |t| t.as(String)        }
        clause(:TRUE)         { |t| true                }
        clause(:FALSE)        { |t| false               }
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
        clause("name COLON input_value") do |name, _, value|
          cvalue = (
            value.is_a?(Array) ? value.map{|v| v.as(ArgumentValue)} : value
          ).as(ArgumentValue)
          Argument.new(name: name, value: cvalue)
        end
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
        clause("DIR_SIGN name arguments?") do |_, name, arguments|
          Directive.new(name: name, arguments: arguments || Array(Argument).new )
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
        clause(:schema_definition)
        clause(:type_definition)
        clause(:directive_definition)
      end

      production(:schema_definition) do
        clause(
          "SCHEMA LCURLY operation_type_definition_list RCURLY"
        ) do |_, _, definitions|
          definitions = definitions.as(Hash(String, CLTK::Type))
          SchemaDefinition.new(
            query: definitions["query"]?,
            mutation: definitions["mutation"]?,
            subscription: definitions["subscription"]?
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
        clause(:scalar_type_definition)
        clause(:object_type_definition)
        clause(:interface_type_definition)
        clause(:union_type_definition)
        clause(:enum_type_definition)
        clause(:input_object_type_definition)
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
                                    interfaces: interfaces || [] of String,
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
          InputValueDefinition.new(
            name: name, type: type,
            default_value: (default_value.is_a?(Array) ?
                              default_value.map &.as(FValue) :
                              default_value).as(FValue),
            directives: directives)
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
          FieldDefinition.new(name: name, arguments: arguments || [] of Argument,
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

      build_nonempty_list_production(
        :union_members,
        :name,
        :PIPE
      )

      #      production(:union_members) do
#        clause(:name) {|name| [TypeName.new(name: name)] }
#        clause("union_members PIPE name") {|members, _, name| members.as(Array(CLTK::Type)) << TypeName.new(name: name)}
#      end

      production(:union_type_definition) do
        clause("UNION name directives_list_opt EQUALS union_members") do |_, name, directives, _, members|
          UnionTypeDefinition.new(name: name,
                                  types: members.as(Array).map { |name| TypeName.new(name: name) }.as(Array(TypeName)),
                                  directives: directives, description: "")
        end
      end

      production(:enum_type_definition) do
        clause("ENUM name directives_list_opt LCURLY enum_value_definitions RCURLY") do |_, name, directives, _,values|
          EnumTypeDefinition.new(name: name, fvalues: values.as(Array), directives: directives, description: "")
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
