module DataType
  include ::GraphQL::ObjectType
  extend self
  field :a { "Apple" }
  field :b { "Banana" }
  field :c { "Cookie" }
  field :d { "Donut" }
  field :e { "Egg" }
  field :f { "Fish" }
  field :pic { |args| "Pic of size: #{ args["size"]? || 50 }" }
  field :deep { DeepDataType }
  field :promise { DataType }
end

module DeepDataType
  include ::GraphQL::ObjectType
  extend self
  field :a { "Already Been Done" }
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
      a: String
      b: String
      c: String
      d: String
      e: String
      f: String
      pic(size: Int): String
      deep: DeepDataType
      promise: DataType
    }

    type DeepDataType {
      a: String
      b: String
      c: [String]
      deeper: [DeepDataType]
    }
  }
)
GO_GRAPHQL_TEST_SCHEMA.query_resolver = DataType
