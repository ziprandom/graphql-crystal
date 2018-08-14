require "../../spec_helper"

describe GraphQL::Schema::Schema do
  it "Allows querying the schema for types" do
    query_string = <<-query
      query IntrospectionTypeQuery {
        __schema {
          types {
            name
           }
        }
      }
    query

    expected = {
      "data" => {
        "__schema" => {
          "types" => [
            {
              "name" => "QueryType",
            },
            {
              "name" => "Episode",
            },
            {
              "name" => "Character",
            },
            {
              "name" => "String",
            },
            {
              "name" => "Human",
            },
            {
              "name" => "Droid",
            },
            {
              "name" => "__Schema",
            },
            {
              "name" => "__Type",
            },
            {
              "name" => "__TypeKind",
            },
            {
              "name" => "Boolean",
            },
            {
              "name" => "__Field",
            },
            {
              "name" => "__InputValue",
            },
            {
              "name" => "__EnumValue",
            },
            {
              "name" => "__Directive",
            },
            #           Not Implemented ATM
            #            {
            #              "name" => "__DirectiveLocation"
            #            }
          ],
        },
      },
    }["data"]["__schema"]["types"]

    result = StarWars::Schema.execute(query_string)["data"].as(Hash)["__schema"].as(Hash)["types"].as(Array)
    missing = expected.reject { |element| result.includes? element }
    superfluous = result.reject { |element| expected.includes? element }

    empty = [] of Hash(String, String)
    missing.should eq empty
    pending "it should only return scalar types actually used in the schema" do
      superfluous.should eq empty
    end
  end
end
