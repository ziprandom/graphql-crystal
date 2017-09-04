module GraphQL
  module Schema
    module Introspection

      macro included
        include ObjectType

        field :types { @original_types.not_nil! }
        field :directives { @directive_definitions.values }
        field :queryType { @original_query }
        field :mutationType { @mutation ? types[@mutation.not_nil!.name] : nil }

        macro finished
          # a clone of @query with the
          # meta fields removed
          @original_query : Language::ObjectTypeDefinition?
          @original_types : Array(Language::TypeDefinition)?

          def initialize(document : Language::Document)
            previous_def(document)
            @original_query = types[@query.not_nil!.name].clone.as(Language::ObjectTypeDefinition)

            # add introspection types to
            # schemas types index
            _schema, _types, _directives = extract_elements(
                               GraphQL::Language.parse(INTROSPECTION_TYPES)
                             )
            @types.merge!( _types.reject("schema") )
            @directive_definitions.merge! _directives

            # keep the original query within the
            # array used for introspection
            @original_types = types.values.
                              compact_map { |t| t.name == @query ? @original_query : t }

            # add the schema field to the root query of
            # the schema
            if root_query = @query
              root_query.fields << Language::FieldDefinition.new(
                "__schema", Array(Language::InputValueDefinition).new,
                Language::TypeName.new(name: "__Schema"), Array(Language::Directive).new,
                "query the schema served at this endpoint"
              )
              root_query.fields << Language::FieldDefinition.new(
                "__type", [
                  Language::InputValueDefinition.new(
                  name: "name", type: Language::TypeName.new(name: "String"), default_value: nil,
                  directives: [] of Language::Directive, description: ""
                )
                ], Language::TypeName.new(name: "__Type"), Array(Language::Directive).new,
                "query a specific type in the schema by name"
              )
            end
            # add the callback for
            # the schema field of
            # the root query
            query(:__schema) do
              self
            end
            query(:__type) do |args|
              @types[args["name"]]
            end
          end
        end

      end

      INTROSPECTION_TYPES = <<-schema

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

        # Optionally includes selection from the result set
        directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
        # Optionally excludes selection from the result set
        directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
        # Marks an element of a GraphQL schema as no longer supported.
        directive @deprecated(reason: String = "No longer supported") on FIELD_DEFINITION | ENUM_VALUE

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
          locations: [__DirectiveLocation!]!
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
      field :kind { nil }
      field :name
      field :description
      field :inputFields { nil }
      field :fields { nil }
      field :interfaces { nil }
      field :possibleTypes { nil }
      field :enumValues { nil } #(includeDeprecated: Boolean = false)
      field :ofType { nil }
      field :isDeprecated { false }
      field :deprecationReason { nil }
    end

    class GraphQL::Language::ObjectTypeDefinition
      field :kind { "OBJECT" }
      field :fields do |args, context|
        _fields = (resolved_interfaces(context.schema).flat_map(&.fields) + fields)
          .reduce(Hash(String, FieldDefinition).new) do |dict, field|
          dict[field.name] = field
          dict
        end.values.sort_by &.name
        if args["includeDeprecated"]
          _fields
        else
          _fields.reject( &.directives.any?( &.name.==("deprecated") ) )
        end
      end
      field :interfaces { |args, context| resolved_interfaces(context.schema) }

      def resolved_interfaces(schema)
        interfaces.map do |iface_name|
          schema.type_resolve(iface_name).as(InterfaceTypeDefinition)
        end
      end
    end

    class GraphQL::Language::UnionTypeDefinition
      field :kind { "UNION" }
      field :possibleTypes { |args, context| types.map{|t| context.schema.type_resolve(t)} }
    end

    class GraphQL::Language::InterfaceTypeDefinition
      field :kind { "INTERFACE" }
      field :possibleTypes do |args, context|
        context.schema.types.values.select do |t|
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
      field :ofType { |args, context| context.schema.type_resolve(of_type) }
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
      include GraphQL::Directives::IsDeprecated
      field :name
      field :description
      field :args { self.arguments }
      field :type { |args, context| context.schema.type_resolve(type) }
    end

    class GraphQL::Language::InputObjectTypeDefinition
      field :inputFields { fields }
      field :kind { "INPUT_OBJECT" }
      field :directives
    end

    class GraphQL::Language::InputValueDefinition
      field :name
      field :description
      field :type { |args, context| context.schema.type_resolve(type) }
      field :defaultValue do
        val = (
          default_value.is_a?(Language::AbstractNode) ?
            GraphQL::Language::Generation.generate(default_value) :
            (
              default_value.is_a?(String) ?
                # quote the string value
                %{"#{default_value}"} :
                default_value
            )
        )
        val == nil ? nil : val.to_s
      end
    end

    class GraphQL::Language::DirectiveDefinition
      field :name
      field :description
      field :args { arguments }
      field :locations
      field :onOperation { locations.includes? "OPERATION" }
      field :onFragment  { locations.any? &.=~ /FRAGMENT/  }
      field :onField     { locations.includes? "FIELD"     }
    end

    class GraphQL::Language::EnumValueDefinition
      include GraphQL::Directives::IsDeprecated
      field :name
      field :description
    end

  end

end
