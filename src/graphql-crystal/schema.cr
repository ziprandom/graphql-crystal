require "./types/object_type"
require "./types/scalar_types"
require "./types/type"
require "./schema/fragment_resolver"
require "./schema/variable_resolver.cr"
require "./schema/validation.cr"
require "./schema/from_schema.cr"

module GraphQL
  module Schema

    macro extended
      include GraphQL::ObjectType

      def self.execute(document : GraphQL::Language::Document, params)
        queries, mutations, fragments = GraphQL::Schema.split_document(document)
        query = queries.first
        query = GraphQL::Schema.substitute_argument_variables(query, params)

        begin
          selections = GraphQL::Schema::FragmentResolver.resolve(
            query.selections.map(&.as(GraphQL::Language::Field)),
            fragments
          )
        rescue e : Exception
          # we hit an error while resolving fragments
          # no path info atm
          return { "data" => nil, "errors" => [{ "message" => e.message, "path" => [] of String}]}
        end

        result, errors = QUERY.resolve( selections )

        res = { "data" =>  result}
        if ( errors.any? )
          error_hash = errors.map do |e|
            ["message", "path"].reduce(nil) do |m, k|
              pair = {k => e[k]}
              m ? m.merge(pair) : pair
            end
          end
          res.merge({ "errors" => error_hash })
        else
          res
        end

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

    def self.split_document(document)
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

    def self.substitute_argument_variables(query : GraphQL::Language::OperationDefinition, params)
      full_params, errors = GraphQL::Schema::Validation.validate_params_against_query_definition(query, params);
      raise "provided params had errors #{errors}" if errors.any?
      GraphQL::Schema::VariableResolver.visit(query, full_params)
    end

  end
end
