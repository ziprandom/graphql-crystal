require "cltk/parser"
module GraphQl
  module Language
    class Parser < CLTK::Parser

      production(:target) do
        clause(:document) { |e| nil }
      end

      production(:document) do
        clause(:definitions_list) { |e| nil }
      end

      build_nonempty_list_production(:definitions_list, :definition)

      production(:definition) do
        clause(:operation_definition)   { |e| nil }
        clause(:fragment_definition)    { |e| nil }
        clause(:type_system_definition) { |e| nil }
      end

      production(:operation_definition) do
        clause("operation_type operation_name? variable_definitions? directives_list_opt selection_set") { |e| nil }
        clause("selection_set") { |e| nil }
      end

      production(:operation_type) do
        clause(:QUERY) { |e| nil }
        clause(:MUTATION) { |e| nil }
        clause(:SUBSCRIPTION) { |e| nil }
      end

      production(:operation_name) do
        clause(:name) { |e| nil }
      end

      production(:variable_definitions) do
        clause("LPAREN variable_definitions_list RPAREN") { |_, e, _| nil }
      end

      build_nonempty_list_production(:variable_definitions_list, :variable_definition)

      production(:variable_definition) do
        clause("VAR_SIGN name COLON type default_value?") { |_, name, _, type, default_value| nil }
      end

      production(:type) do
        clause(:name) { |e| nil }
        clause("type BANG") { |e| nil }
        clause("LBRACKET type RBRACKET") { |_, type, _| nil }
      end

      production(:default_value) do
        clause("EQUALS input_value") { |_, val| nil }
      end

      production(:selection_set) do
        clause("LCURLY RCURLY") { nil }
        clause("LCURLY selection_list RCURLY") { |_, list, _|  nil }
      end

      build_list_production(:selection_list, :selection)

      production(:selection) do
        clause(:field) { |e| nil }
        clause(:fragment_spread) { |e| nil }
        clause(:inline_fragment) { |e| nil }
      end

      production(:field) do
        clause("name arguments? directives_list_opt selection_set?") { |e| nil }
        clause("name COLON name arguments? directives_list_opt selection_set?") { |e| nil }
      end

      production(:schema_keyword) do
        clause(:SCHEMA) { |e| nil }
        clause(:SCALAR) { |e| nil }
        clause(:TYPE) { |e| nil }
        clause(:IMPLEMENTS) { |e| nil }
        clause(:INTERFACE) { |e| nil }
        clause(:UNION) { |e| nil }
        clause(:ENUM) { |e| nil }
        clause(:INPUT) { |e| nil }
        clause(:DIRECTIVE) { |e| nil }
      end

      production(:name) do
        clause(:name_without_on) { |e| nil }
        clause(:ON) { |e| nil }
      end

      production(:name_without_on) do
        clause(:IDENTIFIER) { |e| nil }
        clause(:FRAGMENT) { |e| nil }
        clause(:TRUE) { |e| nil }
        clause(:FALSE) { |e| nil }
        clause(:operation_type) { |e| nil }
        clause(:schema_keyword) { |e| nil }
      end

      production(:enum_name) do
        clause(:IDENTIFIER) { |e| nil }
        clause(:FRAGMENT) { |e|  nil }
        clause(:ON) { |e| nil }
        clause(:operation_type) { |e| nil }
        clause(:schema_keyword) { |e| nil }
      end  # /* any identifier, but not "true", "false" or "null" */

      build_nonempty_list_production(:name_list, :name)

      production(:enum_value_definition) do
        clause("enum_name directives_list_opt") {|e| nil}
      end

      build_nonempty_list_production(:enum_value_definitions, :enum_value_definition)

      production(:arguments) do
        clause("LPAREN RPAREN") { nil }
        clause("LPAREN arguments_list RPAREN")  { |_, list, _| nil }
      end

      build_nonempty_list_production(:arguments_list, :argument)

      production(:argument) do
        clause("name COLON input_value") { |name, _, value| nil }
      end

      production(:input_value) do
        clause(:FLOAT)        { |e| nil }
        clause(:INT)          { |e| nil }
        clause(:STRING)       { |e| nil }
        clause(:TRUE)         { |e| nil }
        clause(:FALSE)        { |e| nil }
        clause(:null_value)   { |e| nil }
        clause(:variable)     { |e| nil }
        clause(:list_value)   { |e| nil }
        clause(:object_value) { |e| nil }
        clause(:enum_value)   { |e| nil }
      end

      production(:null_value) do
        clause(:NULL) { |e| nil }
      end

      production(:variable) do
        clause("VAR_SIGN name") { |_, name| nil }
      end

      production(:list_value) do
        clause("LBRACKET RBRACKET") { nil }
        clause("LBRACKET list_value_list RBRACKET") { |_, list, _| nil }
      end

      build_nonempty_list_production(:list_value_list, :input_value)

      production(:object_value) do
        clause("LCURLY RCURLY") { nil }
        clause("LCURLY object_value_list RCURLY") { |_, list, _| nil }
      end

      build_nonempty_list_production(:object_value_list, :object_value_field)

      production(:object_value_field) do
        clause("name COLON input_value") { |name, _, value| nil }
      end

      production(:enum_value) do
        clause(:enum_name) { nil }
      end

      build_list_production(:directives_list_opt, :directive, nil)

      build_nonempty_list_production(:directives_list, :directive)

      production(:directive) do
        clause("DIR_SIGN name arguments?") { nil }
      end

      production(:fragment_spread) do
        clause("ELLIPSIS name_without_on directives_list_opt") { nil }
      end

      production(:inline_fragment) do
        clause("ELLIPSIS ON type directives_list_opt selection_set") { nil }
        clause("ELLIPSIS directives_list_opt selection_set") { nil }
      end

      production(:fragment_definition) do
        clause("FRAGMENT name_without_on? ON type directives_list_opt selection_set") { nil}
      end

      production(:type_system_definition) do
        clause(:schema_definition) { nil }
        clause(:type_definition) { nil }
        clause(:directive_definition) { nil }
      end

      production(:schema_definition) do
        clause("SCHEMA LCURLY operation_type_definition_list RCURLY") { nil }
      end

      build_nonempty_list_production(:operation_type_definition_list, :operation_type_definition)

      production(:operation_type_definition) do
        clause("operation_type COLON name") { nil } # { return { val[0].to_s.to_sym => val[2] } }
      end

      production(:type_definition) do
        clause(:scalar_type_definition) { nil }
        clause(:object_type_definition) { nil }
        clause(:interface_type_definition) { nil }
        clause(:union_type_definition) { nil }
        clause(:enum_type_definition) { nil }
        clause(:input_object_type_definition) { nil }
      end

      production(:scalar_type_definition) do
        clause("SCALAR name directives_list_opt") { nil }
      end

      production(:object_type_definition) do
        clause("TYPE name implements? directives_list_opt LCURLY field_definition_list RCURLY") { nil }
      end

      production(:implements) do
        clause("IMPLEMENTS name_list") { | _, name| nil }
      end

      production(:input_value_definition) do
        clause("name COLON type default_value? directives_list_opt") { nil }
      end

      build_nonempty_list_production(:input_value_definition_list, :input_value_definition)

      production(:arguments_definitions) do
        clause("LPAREN input_value_definition_list RPAREN") { |_, list, _| nil }
      end

      production(:field_definition) do
        clause("name arguments_definitions? COLON type directives_list_opt") { |e| nil }
      end

      build_list_production(:field_definition_list, :field_definition)

      production(:interface_type_definition) do
        clause("INTERFACE name directives_list_opt LCURLY field_definition_list RCURLY") { nil }
      end

      build_nonempty_list_production(:union_members, :name, :PIPE)

      production(:union_type_definition) do
        clause("UNION name directives_list_opt EQUALS union_members") { nil }
      end

      production(:enum_type_definition) do
        clause("ENUM name directives_list_opt LCURLY enum_value_definitions RCURLY") { nil }
      end

      production(:input_object_type_definition) do
        clause("INPUT name directives_list_opt LCURLY input_value_definition_list RCURLY") { nil }
      end

      production(:directive_definition) do
        clause("DIRECTIVE DIR_SIGN name arguments_definitions? ON directive_locations") { nil }
      end

      build_nonempty_list_production(:directive_locations, :name, :PIPE)

      finalize
    end
  end
end
