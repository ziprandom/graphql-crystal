require "./types/object_type"
require "./types/scalar_types"
require "./schema/fragment_resolver"
require "./schema/variable_resolver.cr"
require "./schema/validation.cr"

module GraphQL
  module Schema

    macro extended
      include GraphQL::ObjectType

      def self.substitute_argument_variables(query : GraphQL::Language::OperationDefinition, params)
        full_params, errors = GraphQL::Schema::Validation.validate_params_against_query_definition(query, params);
        raise "provided params had errors #{errors}" if errors.any?
        GraphQL::Schema::VariableResolver.visit(query, full_params)
      end

      def self.execute(document : GraphQL::Language::Document, params)
        queries, mutations, fragments = split_document(document)
        query = queries.first
        query = substitute_argument_variables(query, params)

        selections = GraphQL::Schema::FragmentResolver.resolve(
          query.selections.map(&.as(GraphQL::Language::Field)),
          fragments
        )

        { "data" => QUERY.resolve( selections ) }
      end

      def self.execute(query_string, params = nil)
        self.execute( GraphQL::Language.parse(query_string, nil), params)
      end

      macro query(query)
        QUERY = \{{query}}
      end

      macro finished
        \\{{ raise "no query specified for schema: #{@type}" unless @type.has_constant?("QUERY") }}
      end

    end

    def split_document(document)
      queries = Array(GraphQL::Language::OperationDefinition).new
      mutations = Array(GraphQL::Language::OperationDefinition).new
      fragments = Array(GraphQL::Language::FragmentDefinition).new
      document.definitions.each do |definition|
        case definition
        when GraphQL::Language::OperationDefinition
          definition.operation_type == "query" ?
            queries << definition :
            mutations << definition
        when GraphQL::Language::FragmentDefinition
          fragments << definition
        end
      end
      {queries, mutations, fragments}
    end

  end
end
