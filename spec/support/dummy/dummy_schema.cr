require "./dummy_data"
require "./dummy_schema_string"
require "../../../src/graphql-crystal/schema";

def fetchItem(type, data : Hash)
  Proc(Hash(String, GraphQL::Schema::ReturnType), GraphQL::Schema::ResolveCBReturnType).new do |args|
    data.find(&.[0].to_s.==(args["id"].to_s)).not_nil![1].as(GraphQL::Schema::ResolveCBReturnType)
  end
end

module Dummy
  Schema = GraphQL::Schema.from_schema(Dummy::SCHEMA_STRING).resolve do
    query :cheese { |args| fetchItem(Cheese, CHEESES).call(args) }
    query :milk { |args| fetchItem(Milk, MILKS).call(args) }
    query :dairy { DAIRY }
    query :favouriteEdible { MILKS[1] }
    query :cow { COW }
    query :searchDairy do |args|
      source = args["product"].as(Array).first.as(Hash)["source"]
      products = CHEESES.values + MILKS.values
      if source
        products.select &.source.==(source)
      else
        products.first
      end
    end
    query :allDairy do |args|
      result = CHEESES.values + MILKS.values
    end

    query :allEdible { CHEESES.values + MILKS.values }
    query :error { raise("This error was raised on purpose") }
    query :executionError { raise("I don't have a dedicated ExecutionErrorObject :(" ) }
    query :maybeNull { Dummy::MAYBE_NULL }
    query :deepNonNull { nil }

    mutation :pushValue do |args|
      args["value"]
    end

    mutation :replaceValues do |args|
      CHEESES.values + MILKS.values
    end
  end
end
