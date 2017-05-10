module GraphQL
  module Schema
    #
    # Traverse the Queries AST and replace VariableIdentifiers
    # with the variables provided in params
    class VariableResolver

      def self.visit(query : GraphQL::Language::OperationDefinition, params)
        query.tap &.selections = visit(query.selections, params).map &.as(GraphQL::Language::AbstractNode)
      end

      def self.visit(fields : Array(GraphQL::Language::AbstractNode), params)
        fields.map { |field| visit field, params }
      end

      def self.visit(field : GraphQL::Language::Field, params)
        field.tap do |field|
          field.selections = visit(field.selections, params).map &.as(GraphQL::Language::Selection)
          field.arguments = visit(field.arguments, params).map &.as(GraphQL::Language::Argument)
        end
      end

      def self.visit(argument : GraphQL::Language::Argument, params)
        argument.tap &.value = visit(argument.value, params).as(GraphQL::Language::ArgumentValue)
      end

      def self.visit(variable : GraphQL::Language::VariableIdentifier, params)
        params[variable.name]
      end

      def self.visit(field, params)
        field
      end

    end
  end
end
