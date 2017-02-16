require "cltk/ast"
require "cltk/token"


module GraphQL
  module Language

    class AbstractNode < CLTK::ASTNode
 #     getter :line, :col
 #     @col : Int32
 #     @line : Int32
#
 #     def initialize(**options)
 #       position_source = options.fetch(:position_source, nil)
 #       if position_source
##          @line, @col = position_source.as(Array(Int32)).line_and_column
 #       end
 #       super()
 #     end
    end



    # This is the AST root for normal queries
    #
    # @example Deriving a document by parsing a string
    #   document = GraphQL.parse(query_string)
    #
    # @example Creating a string from a document
    #   document.to_query_string
    #   # { ... }
    #
    class Document < AbstractNode
      values({definitions: Array(OperationDefinition|FragmentDefinition)})
      as_children([:definitions])

      #  def slice_definition(name)
      #    GraphQL::Language::DefinitionSlice.slice(self, name)
      #  end
    end


    class SchemaDefinition < AbstractNode
      values({query: OperationDefinition, mutation: OperationDefinition?, subscription: OperationDefinition?})
    end

    # A query, mutation or subscription.
    # May be anonymous or named.
    # May be explicitly typed (eg `mutation { ... }`) or implicitly a query (eg `{ ... }`).
    class OperationDefinition < AbstractNode
      values(
        {
          operation_type: String,
          name: String?,
          variables: Array(VariableDefinition),
          directives: Array(Directive),
          selections: Array(Selection)}
      )
      as_children([:variables, :directives, :selections])
    end

    class DirectiveDefinition < AbstractNode
      values({name: String, arguments: Array(Argument), locations: Array(NameOnlyNode)})
    end

    class Directive < AbstractNode
      values({name: String, arguments: Array(Argument)})
    end

    alias FValue = String | Int32 | Float32 | Bool |  Nil | AEnum | Array(FValue)
    alias Type = TypeName | NonNullType | ListType
    alias Selection = Field | FragmentSpread | InlineFragment

    class VariableDefinition < AbstractNode
      values({name: String, type: Type, default_value: FValue})
    end

    alias ArgumentValue = String | Int32 | Float32 | Bool | InputObject | VariableIdentifier | Array(ArgumentValue)

    class Argument < AbstractNode
      values({name: String, value: ArgumentValue})
    end

    class ScalarTypeDefinition < AbstractNode
      values({name: String, directives: Array(Directive), description: String})
      as_children([:directives])
    end

    class ObjectTypeDefinition < AbstractNode
      values(
        {name: String,
         interfaces: Array(String),
         fields: Array(FieldDefinition),
         directives: Array(Directive),
         description: String}
      )
      as_children([:interfaces, :fields, :directives])
    end

    class InputObjectTypeDefinition < AbstractNode
      values({name: String, fields: Array(Field), directives: Array(Directive), description: String})
    end

    class InputValueDefinition < AbstractNode
      values({name: String, type: Type, default_value: FValue, directives: Array(Directive)})
    end

    # Base class for nodes whose only value is a name (no child nodes or other scalars)
    class NameOnlyNode < AbstractNode
      values({name: String})
    end

    # Base class for non-null type names and list type names
    class WrapperType < AbstractNode
      values({ of_type: (TypeName|NonNullType|ListType) })
    end

    # A type name, used for variable definitions
    class TypeName < NameOnlyNode; end

    # A list type definition, denoted with `[...]` (used for variable type definitions)
    class ListType < WrapperType; end
    # A collection of key-value inputs which may be a field argument

    class InputObject < AbstractNode
      values({arguments: Array(Argument)})
      as_children([:arguments])

      # @return [Hash<String, Any>] Recursively turn this input object into a Ruby Hash
      def to_h()
        arguments.inject({} of String => FValue) do |memo, pair|
          v = pair.value
          memo[pair.name] = v.is_a?(InputObject) ? v.to_h : v
          memo
        end
      end
    end
    # A non-null type definition, denoted with `...!` (used for variable type definitions)
    class NonNullType < WrapperType; end

    # An enum value. The string is available as {#name}.
    class AEnum < NameOnlyNode; end

    # A null value literal.
    class NullValue < NameOnlyNode; end

    class VariableIdentifier < NameOnlyNode; end

    # A single selection in a
    # A single selection in a GraphQL query.
    class Field < AbstractNode
      values({
               name: String,
               alias: String?,
               arguments: Array(Argument),
               directives: Array(Directive),
               selections: Array(Selection)
             })
      as_children([:arguments, :directives, :selections])
    end

    class FragmentDefinition < AbstractNode
      values({
               name: String?,
               type: Type,
               directives: Array(Directive),
               selections: Array(Selection)
             })
    end


    class FieldDefinition < AbstractNode
      values({name: String, arguments: Array(InputValueDefinition), type: Type, directives: Array(Directive), description: String})
      as_children([:arguments, :directives])
    end

    class InterfaceTypeDefinition < AbstractNode
      values({name: String, fields: Array(Field), directives: Array(Directive), description: String})
      as_children([:fields, :directives])
    end


    class UnionTypeDefinition < AbstractNode
      values({name: String, types: Array(Type), directives: Array(Directive), description: String})
      as_children([:types, :directives])
    end

    class EnumTypeDefinition < AbstractNode
      values({name: String, fvalues: Array(FValue), directives: Array(Directive), description: String})
      as_children([:values, :directives])
    end

    # Application of a named fragment in a selection
    class FragmentSpread < AbstractNode
      values({ name: String, directives: Array(Directive) })
      as_children([:directives])
    end

    # An unnamed fragment, defined directly in the query with `... {  }`
    class InlineFragment < AbstractNode
      values({ type: Type?, directives: Array(Directive), selections: Array(Selection) })
      as_children([:directives, :selections])
    end

    class EnumValueDefinition < AbstractNode
      values({name: String, directives: Array(Directive), selection: Array(Selection)? })
      as_children([:directives])
    end
  end
end
