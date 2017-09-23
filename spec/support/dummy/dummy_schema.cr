require "./dummy_data"
require "./dummy_schema_string"
require "../../../src/graphql-crystal/schema";

# def fetchItem(type, data : Hash)
#   Proc(Hash(String, JSON::Type), JSON::Type).new do |args|
#     data.find(&.[0].to_s.==(args["id"].to_s)).not_nil![1].as(JSON::Type)
#   end
# end

module Dummy

  module DairyAppQuery
    include ::GraphQL::ObjectType
    extend self

    #    field :cheese { |args| fetchItem(Cheese, CHEESES).call(args.as(Hash(String,JSON::Type))) }
    #    field :milk { |args| fetchItem(Milk, MILKS).call(args.as(Hash(String,JSON::Type))) }

    field :dairy { DAIRY }
    field :favouriteEdible { MILKS[1] }
    field :cow { COW }
    field :searchDairy do |args|
      source = args["product"].as(Array).first.as(Hash)["source"]
      products = CHEESES.values + MILKS.values
      if source
        products.select &.source.==(source)
      else
        products.first
      end
    end
    field :allDairy do |args|
      result = CHEESES.values + MILKS.values
    end

    field :allEdible { CHEESES.values + MILKS.values }
    field :error { raise("This error was raised on purpose") }
    field :executionError { raise("I don't have a dedicated ExecutionErrorObject :(" ) }
    field :maybeNull { Dummy::MAYBE_NULL }
    field :deepNonNull { nil }
  end

  module DairyAppMutation
    include ::GraphQL::ObjectType
    extend self

    field :pushValue do |args|
      args["value"]
    end

    field :replaceValues do |args|
      CHEESES.values + MILKS.values
    end

  end

  Schema = GraphQL::Schema.from_schema(Dummy::SCHEMA_STRING)
  Schema.query_resolver = DairyAppQuery
  Schema.mutation_resolver = DairyAppMutation

end
