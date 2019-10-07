require "json"

module GraphQL
  module Language
    # Exposes {.generate}, which turns AST nodes back into query strings.
    # Turn an AST node back into a string.
    #
    # @example Turning a document into a query
    #    document = GraphQL.parse(query_string)
    #    Generation.generate(document)
    #    # => "{ ... }"
    #
    # @param node [AbstractNode] an AST node to recursively stringify
    # @param indent [String] Whitespace to add to each printed node
    # @return [String] Valid GraphQL for `node`
    module Generation
      def self.generate(node : Document, indent : String = "")
        node.definitions.map { |d| generate(d) }.join("\n\n")
      end

      def self.generate(node : Argument, indent : String = "")
        "#{node.name}: #{generate(node.value)}"
      end

      def self.generate(node : Directive, indent : String = "")
        out = "@#{node.name}"
        out += "(#{node.arguments.map { |a| generate(a).as(String) }.join(", ")})" if node.arguments.any?
        out
      end

      def self.generate(node : AEnum, indent : String = "")
        "#{node.name}"
      end

      def self.generate(node : NullValue, indent : String = "")
        "null"
      end

      def self.generate(node : Field, indent : String = "")
        out = ""
        out += "#{node._alias}: " if node._alias
        out += "#{node.name}"
        out += "(#{node.arguments.map { |a| generate(a).as(String) }.join(", ")})" if node.arguments.any?
        out += generate_directives(node.directives)
        out += generate_selections(node.selections, indent: indent)
        out
      end

      def self.generate(node : FragmentDefinition, indent : String = "")
        out = "#{indent}fragment #{node.name}"
        if node.type
          out += " on #{generate(node.type)}"
        end
        out += generate_directives(node.directives)
        out += generate_selections(node.selections, indent: indent)
        out
      end

      def self.generate(node : FragmentSpread, indent : String = "")
        out = "#{indent}...#{node.name}"
        if node.directives.any?
          out += " " + node.directives.map { |d| generate(d).as(String) }.join(" ")
        end
      end

      def self.generate(node : InlineFragment, indent : String = "")
        out = "#{indent}..."
        if node.type
          out += " on #{generate(node.type)}"
        end
        out += generate_directives(node.directives)
        out += generate_selections(node.selections, indent: indent)
        out
      end

      def self.generate(node : InputObject, indent : String = "")
        generate(node.to_h)
      end

      def self.generate(node : ListType, indent : String = "")
        "[#{generate(node.of_type)}]"
      end

      def self.generate(node : NonNullType, indent : String = "")
        "#{generate(node.of_type)}!"
      end

      def self.generate(node : OperationDefinition, indent : String = "")
        out = "#{indent}#{node.operation_type}"
        if node.name
          out += " #{node.name}"
        end
        out += "(#{node.variables.map { |v| generate(v) }.join(", ")})" if node.variables.any?
        out += generate_directives(node.directives)
        out += generate_selections(node.selections, indent: indent)
        out
      end

      def self.generate(node : TypeName, indent : String = "")
        "#{node.name}"
      end

      def self.generate(node : VariableDefinition)
        out = "$#{node.name}: #{generate(node.type)}"
        unless node.default_value.nil?
          out += " = #{generate(node.default_value)}"
        end
        out
      end

      def self.generate(node : VariableIdentifier, indent : String = "")
        "$#{node.name}"
      end

      def self.generate(node : SchemaDefinition, indent : String = "")
        if (node.query.nil? || node.query == "Query") &&
           (node.mutation.nil? || node.mutation == "Mutation") &&
           (node.subscription.nil? || node.subscription == "Subscription")
          return ""
        end
        out = "schema {\n"
        out += "  query: #{node.query}\n" if node.query
        out += "  mutation: #{node.mutation}\n" if node.mutation
        out += "  subscription: #{node.subscription}\n" if node.subscription
        out += "}"
      end

      def self.generate(node : ScalarTypeDefinition, indent : String = "")
        out = generate_description(node)
        out += "scalar #{node.name}"
        out += generate_directives(node.directives)
      end

      def self.generate(node : ObjectTypeDefinition, indent : String = "")
        out = generate_description(node)
        out += "type #{node.name}"
        out += generate_directives(node.directives)
        out += " implements " + node.interfaces.map { |i| i.as(String) }.join(", ") unless node.interfaces.empty?
        out += generate_field_definitions(node.fields)
      end

      def self.generate(node : InputValueDefinition, indent : String = "")
        out = "#{node.name}: #{generate(node.type)}"
        out += " = #{generate(node.default_value)}" unless node.default_value.nil?
        out += generate_directives(node.directives)
      end

      def self.generate(node : FieldDefinition, indent : String = "")
        out = node.name.dup
        unless node.arguments.empty?
          out += "(" + node.arguments.map { |arg| generate(arg).as(String) }.join(", ") + ")"
        end
        out += ": #{generate(node.type)}"
        out += generate_directives(node.directives)
      end

      def self.generate(node : InterfaceTypeDefinition, indent : String = "")
        out = generate_description(node)
        out += "interface #{node.name}"
        out += generate_directives(node.directives)
        out += generate_field_definitions(node.fields)
      end

      def self.generate(node : UnionTypeDefinition, indent : String = "")
        out = generate_description(node)
        out += "union #{node.name}"
        out += generate_directives(node.directives)
        out += " = " + node.types.map { |t| t.as(NameOnlyNode).name }.join(" | ")
      end

      def self.generate(node : EnumTypeDefinition, indent : String = "")
        out = generate_description(node)
        out += "enum #{node.name}#{generate_directives(node.directives)} {\n"
        node.fvalues.each_with_index do |value, i|
          out += generate_description(value, indent: "  ", first_in_block: i == 0)
          out += generate(value) || ""
        end
        out += "}"
      end

      def self.generate(node : EnumValueDefinition, indent : String = "")
        out = "  #{node.name}"
        out += generate_directives(node.directives)
        out += "\n"
      end

      def self.generate(node : InputObjectTypeDefinition, indent : String = "")
        out = generate_description(node)
        out += "input #{node.name}"
        out += generate_directives(node.directives)
        out += " {\n"
        node.fields.each.with_index do |field, i|
          out += generate_description(field, indent: "  ", first_in_block: i == 0)
          out += "  #{generate(field)}\n"
        end
        out += "}"
      end

      def self.generate(node : DirectiveDefinition, indent : String = "")
        out = generate_description(node)
        out += "directive @#{node.name}"
        out += "(#{node.arguments.map { |a| generate(a).as(String) }.join(", ")})" if node.arguments.any?
        out += " on #{node.locations.join(" | ")}"
      end

      #      def self.generate(node : AbstractNode, indent : String = "")
      #        node.to_query_string()
      #      end

      def self.generate(node : Float | Int | String | Nil | Bool, indent : String = "")
        node.to_json
      end

      def self.generate(node : Symbol, indent : String = "")
        node.to_s.capitalize
      end

      def self.generate(node : Array, indent : String = "")
        "[#{node.map { |v| generate(v) }.join(", ")}]"
      end

      def self.generate(node : Hash, indent : String = "")
        value = node.map { |k, v| "#{k}: #{generate(v)}" }.join(", ")
        "{#{value}}"
      end

      def self.generate(node, indent : String = "")
        raise "TypeError (please define it :) )"
        ""
      end

      def self.generate_directives(directives, indent : String = "")
        if directives.any?
          directives.map { |d| " #{generate(d)}" }.join
        else
          ""
        end
      end

      def self.generate_selections(selections, indent : String = "")
        if selections.any?
          out = " {\n"
          selections.each do |selection|
            out += generate(selection, indent: indent + "  ").to_s + "\n"
          end
          out += "#{indent}}"
        else
          ""
        end
      end

      def self.generate_description(node, indent = "", first_in_block = true)
        return "" unless node.description

        description = indent != "" && !first_in_block ? "\n" : ""
        description += "#{indent}# #{node.description}\n"
      end

      def self.generate_field_definitions(fields, indent : String = "")
        out = " {\n"
        fields.each.with_index do |field, i|
          out += generate_description(field, indent: "  ", first_in_block: i == 0)
          out += "  #{generate(field)}\n"
        end
        out += "}"
      end
    end
  end
end
