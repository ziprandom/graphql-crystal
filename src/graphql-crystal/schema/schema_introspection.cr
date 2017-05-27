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

        type __Directive {
          name: String!
          description: String
          args: [__InputValue!]!
          onOperation: Boolean!
          onFragment: Boolean!
          onField: Boolean!
        }
      schema
    end
  end

  module Language

    class GraphQL::Language::TypeDefinition
      graphql_type "Type"
      field :kind { self.graphql_type.upcase }
      field :name
      field :description
      field :inputFields {"inputFields"}
    end

    class GraphQL::Language::ObjectTypeDefinition
      graphql_type "Object"
      field :fields
      field :interfaces
      field :possibleTypes { ["dummy"] }
    end

    class GraphQL::Language::UnionTypeDefinition
      graphql_type "Union"
      field :possibleTypes { types }
    end

    class GraphQL::Language::InterfaceTypeDefinition
      graphql_type "Interface"
      field :fields
    end

    class GraphQL::Language::EnumTypeDefinition
      graphql_type "Enum"
      field :enumValues { values }#(includeDeprecated: Boolean = false)
    end

    class GraphQL::Language::WrapperType
      field :kind { "typeKind" }
      field :ofType { of_type }
    end

    class EnumValueDefinition
      field :name
      field :description
      field :isDeprecated { false }
      field :deprecationReason { "" }
    end
  end

end
