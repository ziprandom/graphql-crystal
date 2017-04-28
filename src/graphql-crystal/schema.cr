require "./types/object_type"
require "./types/scalar_types"
module GraphQL
  module Schema

    macro extended
      include GraphQL::ObjectType

      def self.execute(document : GraphQL::Language::Document)
        queries, mutations, fragments = split_document(document)
        query = queries.first
        selections = query.selections.compact_map { |f| f if f.is_a?(GraphQL::Language::Field) }
        result = QUERY.resolve(selections)
        result
      end

      def self.execute(query_string)
        self.execute(GraphQL::Language.parse(query_string))
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
