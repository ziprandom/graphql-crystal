require "./types/object_type"
require "./types/scalar_types"
module GraphQL
  module Schema
    module FragmentResolver

      def self.resolve(value : Array(GraphQL::Language::Field), fragments)
        visit(value, fragments).map &.as(GraphQL::Language::Field)
      end

      def self.visit(values : Array, fragments : Array(GraphQL::Language::FragmentDefinition))
        new_values = Array(GraphQL::Language::AbstractNode).new
        values.each { |v| new_values = new_values + [visit(v, fragments)].flatten }
        new_values
      end

      def self.visit(value : GraphQL::Language::Field, fragments)
        new_values = Array(GraphQL::Language::AbstractNode).new
        value.selections.each do |s|
          new_values = new_values + visit(s, fragments).map &.as(GraphQL::Language::AbstractNode)
        end
        value.selections = new_values.flatten
        [value]
      end

      def self.visit(value : GraphQL::Language::FragmentSpread, fragments)
        fragment_definition = fragments.find(&.name.==(value.name))
        raise "fragment \"#{value.name}\" is undefined" unless fragment_definition
        fragment_definition.selections
      end

      def self.visit(value : GraphQL::Language::InlineFragment, fragments)
        [value]
      end

      def self.visit(value, fragments)
        raise "I should have never arrived here!"
      end
    end

    macro extended
      include GraphQL::ObjectType

      def self.execute(document : GraphQL::Language::Document)
        queries, mutations, fragments = split_document(document)
        query = queries.first
        selections = GraphQL::Schema::FragmentResolver.resolve(
          query.selections.map(&.as(GraphQL::Language::Field)),
          fragments
        )
        { "data" => QUERY.resolve( selections ) }
      end

      private def self.substitute_fragments(
                    selections : Array(GraphQL::Language::Field|GraphQL::Language::FragmentSpread),
                    fragments : Array(GraphQL::Language::FragmentDefinition))
        selections.map do |selection|
          new_sels = substitute_fragments(selection, fragments)
          new_sels.is_a?(Array) ? new_sels.flatten : new_sels
        end
      end

      private def self.substitute_fragments(
                    selection : GraphQL::Language::Field|GraphQL::Language::FragmentSpread,
                    fragments : Array(GraphQL::Language::FragmentDefinition))
        if selection.is_a? GraphQL::Language::Field
          selection.selections = selection.selections.compact_map do |sel|
            if sel.is_a? GraphQL::Language::Field
              substitute_fragments(sel, fragments)
            elsif sel.is_a? GraphQL::Language::FragmentSpread
              substitute_fragments(sel, fragments)
            end
          end.as(Array(GraphQL::Language::AbstractNode))
          selection
        elsif selection.is_a? GraphQL::Language::FragmentSpread
          name = selection.name
          selection = fragments.find(&.name.==(name))
          raise "fragment #{name} is undefined!" unless selection
          selection.selections.as(Array(GraphQL::Language::Field))
        end
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
