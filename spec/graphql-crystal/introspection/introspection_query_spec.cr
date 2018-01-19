require "../../spec_helper"

describe "GraphQL::Introspection::INTROSPECTION_QUERY" do
  query_string = GraphQL::Schema::INTROSPECTION_QUERY
  result = Dummy::Schema.execute(query_string)

  it "runs" do
    result["data"].should be_truthy
  end

  pending "handles deeply nested (<= 7) schemas" do
    query_type = GraphQL::ObjectType.define do
      name "DeepQuery"
      field :foo do
        type !GraphQL::ListType.new(
          of_type: !GraphQL::ListType.new(
            of_type: !GraphQL::ListType.new(
              of_type: GraphQL::FLOAT_TYPE
            )
          )
        )
      end
    end

    deep_schema = GraphQL::Schema.define do
      query query_type
    end

    result = deep_schema.execute(query_string)
    assert(GraphQL::Schema::Loader.load(result))
  end

  pending "doesn't handle too deeply nested (< 8) schemas" do
    query_type = GraphQL::ObjectType.define do
      name "DeepQuery"
      field :foo do
        type !GraphQL::ListType.new(
          of_type: !GraphQL::ListType.new(
            of_type: !GraphQL::ListType.new(
              of_type: !GraphQL::ListType.new(
                of_type: GraphQL::FLOAT_TYPE
              )
            )
          )
        )
      end
    end

    deep_schema = GraphQL::Schema.define do
      query query_type
    end

    result = deep_schema.execute(query_string)
    assert_raises(KeyError) {
      GraphQL::Schema::Loader.load(result)
    }
  end
end
