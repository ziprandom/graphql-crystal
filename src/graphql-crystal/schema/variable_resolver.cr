module GraphQL
  module Schema
    #
    # Visitor to Traverse the Queries AST and replace
    # VariableIdentifiers with the variables provided
    # in params
    class VariableResolver
      def self.visit(query : Language::OperationDefinition, params)
        query.tap &.selections = visit(query.selections, params).map &.as(Language::AbstractNode)
      end

      def self.visit(fields : Array(Language::AbstractNode), params)
        fields.map { |field| visit field, params }
      end

      def self.visit(field : Language::Field, params)
        field.tap do |field|
          field.selections = visit(field.selections, params).map &.as(Language::Selection)
          field.arguments = visit(field.arguments, params).map &.as(Language::Argument)
        end
      end

      def self.visit(argument : Language::Argument, params)
        argument.tap &.value = visit(argument.value, params).as(Language::ArgumentValue)
      end

      def self.visit(variable : Language::VariableIdentifier, params)
        params[variable.name]
      end

      def self.visit(field, params)
        field
      end
    end
  end
end
