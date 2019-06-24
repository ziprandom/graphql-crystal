require "../../spec_helper"
describe "GraphQL::Introspection::SchemaType" do
  query_string = %{
    query getSchema {
      __schema {
        types { name }
        queryType { fields { name }}
        mutationType { fields { name }}
      }
    }
  }
  result = Dummy::Schema.execute(query_string)

  it "exposes the schema" do
    expected = {"data" => {
      "__schema" => {
        "types"     => Dummy::Schema.types.values.map { |t| t.name.nil? ? (p t; raise("no name for #{t}")) : {"name" => t.name} },
        "queryType" => {
          "fields" => [
            {"name" => "allDairy"},
            {"name" => "allEdible"},
            {"name" => "cheese"},
            {"name" => "cow"},
            {"name" => "dairy"},
            {"name" => "deepNonNull"},
            {"name" => "error"},
            {"name" => "executionError"},
            {"name" => "favoriteEdible"},
            {"name" => "fromSource"},
            {"name" => "maybeNull"},
            {"name" => "milk"},
            {"name" => "root"},
            {"name" => "searchDairy"},
            {"name" => "valueWithExecutionError"},
          ],
        },
        "mutationType" => {
          "fields" => [
            {"name" => "pushValue"},
            {"name" => "replaceValues"},
          ],
        },
      },
    }}
    result.should eq expected
  end
end
