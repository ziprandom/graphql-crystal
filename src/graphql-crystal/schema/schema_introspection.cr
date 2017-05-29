module GraphQL
  module Schema
    module Introspection

      macro included
        include ObjectType

        field :types { @types.values }

        macro finished
          def initialize(document : Language::Document)
            previous_def(document)
            # add introspection types to
            # schemas types index
            @types.merge!(
              extract_elements(
                GraphQL::Language.parse(INTROSPECTION_TYPES)
              )[:types].reject("schema")
            )

            # add the schema field to the root query of
            # the schema
            if root_query = @query
              root_query.fields << Language::FieldDefinition.new(
                "__schema", Array(Language::InputValueDefinition).new,
                Language::TypeName.new(name: "__Schema"), Array(Language::Directive).new,
                "the introspection query"
              )
            end
            # add the callback for
            # the schema field of
            # the root query
            query(:__schema) do
              self
            end
          end
        end

      end

      INTROSPECTION_TYPES = <<-schema
        schema {
          query: __Schema
        }

        # A String Value
        scalar String

        # A Boolean Value
        scalar Boolean

        # An Integer Number
        scalar Int

        # A Floating Point Number
        scalar Float

        # An ID
        scalar ID

        type __Schema {
          types: [__Type!]!
          queryType: __Type!
          mutationType: __Type
          directives: [__Directive!]!
        }

        type __Type {
          kind: __TypeKind!
          name: String
          description: String
          # OBJECT and INTERFACE only
          fields(includeDeprecated: Boolean = false): [__Field!]
          # OBJECT only
          interfaces: [__Type!]
          # INTERFACE and UNION only
          possibleTypes: [__Type!]
          # ENUM only
          enumValues(includeDeprecated: Boolean = false): [__EnumValue!]
          # INPUT_OBJECT only
          inputFields: [__InputValue!]
          # NON_NULL and LIST only
          ofType: __Type
        }

        type __Field {
          name: String!
          description: String
          args: [__InputValue!]!
          type: __Type!
          isDeprecated: Boolean!
          deprecationReason: String
        }

        type __InputValue {
          name: String!
          description: String
          type: __Type!
          defaultValue: String
        }

        type __EnumValue {
          name: String!
          description: String
          isDeprecated: Boolean!
          deprecationReason: String
        }

        type __Directive {
          name: String!
          description: String
          args: [__InputValue!]!
          onOperation: Boolean!
          onFragment: Boolean!
          onField: Boolean!
        }

        enum __TypeKind {
          SCALAR
          OBJECT
          INTERFACE
          UNION
          ENUM
          INPUT_OBJECT
          LIST
          NON_NULL
        }

        # A Directive can be adjacent to many parts
        # of the GraphQL language, a __DirectiveLocation
        # describes one such possible adjacencies.
        enum __DirectiveLocation {
          # Location adjacent
          # to a query operation
          QUERY
          # Location adjacent to
          # a mutation operation
          MUTATION
          # Location adjacent to
          # a subscription operation
          SUBSCRIPTION
          # Location adjacent to
          # a field
          FIELD
          # Location adjacent to
          # a fragment definition
          FRAGMENT_DEFINITION
          # Location adjacent to
          # a fragment spread
          FRAGMENT_SPREAD
          # Location adjacent to
          # an inline fragment
          INLINE_FRAGMENT
          # Location adjacent to
          # a schema definition
          SCHEMA
          # Location adjacent to
          # a scalar definition
          SCALAR
          # Location adjacent to
          # an object type definition
          OBJECT
          # Location adjacent to
          # a field definition
          FIELD_DEFINITION
          # Location adjacent to
          # an argument definition
          ARGUMENT_DEFINITION
          # Location adjacent to
          # an interface definition
          INTERFACE
          # Location adjacent to
          # a union definition
          UNION
          # Location adjacent to
          # an enum definition
          ENUM
          # Location adjacent to
          # an enum value definition
          ENUM_VALUE
          # Location adjacent to
          # an input object type definition
          INPUT_OBJECT
          # Location adjacent to
          # an input object field definition
          INPUT_FIELD_DEFINITION
        }
      schema
    end
  end

  module Language

    class GraphQL::Language::TypeDefinition
      field :kind { "OBJECT" }
      field :name
      field :description
      field :inputFields {"inputFields"}
      field :fields { nil }
      field :interfaces { nil }
      field :possibleTypes { nil }
      field :enumValues { nil } #(includeDeprecated: Boolean = false)
      field :ofType { nil }
      field :isDeprecated { false }
      field :deprecationReason { nil }
    end

    class GraphQL::Language::ObjectTypeDefinition
      field :fields do
        fields + resolved_interfaces(schema).flat_map &.fields
      end
      field :interfaces { resolved_interfaces(schema) }

      def resolved_interfaces(schema)
        interfaces.map do |iface_name|
          schema.type_resolve(iface_name).as(InterfaceTypeDefinition)
        end
      end
    end

    class GraphQL::Language::UnionTypeDefinition
      field :possibleTypes { types.map{|t| schema.type_resolve(t)} }
    end

    class GraphQL::Language::InterfaceTypeDefinition
      field :kind { "INTERFACE" }
      field :possibleTypes do
        schema.types.values.select do |t|
          t.is_a?(ObjectTypeDefinition) && t.interfaces.includes?(self.name)
        end
      end
      field :fields
    end

    class GraphQL::Language::EnumTypeDefinition
      field :kind { "ENUM" }
      field :enumValues { self.fvalues }#(includeDeprecated: Boolean = false)
    end

    class GraphQL::Language::WrapperType
      field :name { nil }
      field :ofType { schema.type_resolve(of_type) }
    end

    class GraphQL::Language::ListType
      field :kind { "LIST" }
    end

    class GraphQL::Language::NonNullType
      field :kind { "NON_NULL" }
    end

    class GraphQL::Language::ScalarTypeDefinition
      field :kind { "SCALAR" }
    end

    class GraphQL::Language::FieldDefinition
      field :name
      field :description
      field :args { self.arguments }
      field :type { schema.type_resolve(type) }
      field :isDeprecated { nil }
      field :deprecationReason { "" }
    end

    class GraphQL::Language::InputValueDefinition
      field :name
      field :description
      field :type { schema.type_resolve(type) }
      field :defaultValue { default_value }
    end

    class GraphQL::Language::EnumValueDefinition
      field :name
      field :description
      field :isDeprecated { false }
      field :deprecationReason { "none of your business" }
    end

  end

end
