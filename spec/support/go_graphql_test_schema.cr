module DataType
  include ::GraphQL::ObjectType
  extend self
  field :A { "Apple" }
  field :b { "Banana" }
  field :c { "Cookie" }
  field :d { "Donut" }
  field :e { "Egg" }
  field :f { "Fish" }
  field :Pic { |args| "Pic of size: #{args["size"]? || 50}" }
  field :deep { DeepDataType }
  field :promise { DataType }
end

module DeepDataType
  include ::GraphQL::ObjectType
  extend self
  field :A { "Already Been Done" }
  field :b { "Boring" }
  field :c { ["Contrived", nil, "Confusing"] }
  field :deeper { [self, self] }
end

GO_GRAPHQL_TEST_SCHEMA = ::GraphQL::Schema.from_schema(
  %{
    schema {
      query: DataType
    }

    type DataType {
      A: String
      b: String
      c: String
      d: String
      e: String
      f: String
      Pic(size: Int): String
      deep: DeepDataType
      promise: DataType
    }

    type DeepDataType {
      A: String
      b: String
      c: [String]
      deeper: [DeepDataType]
    }
  }
)
GO_GRAPHQL_TEST_SCHEMA.query_resolver = DataType
