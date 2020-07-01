require "../../spec_helper"

describe "GraphQL::Introspection::DirectiveType" do
  query_string = <<-query_string
    {
      __type(name: "DairyProductInput") {
        name
        description
        kind
        inputFields {
          name
          type { kind, name }
          defaultValue
          description
        }
      }
    }
  query_string
  result = Dummy::SCHEMA.execute(query_string)

  it "shows directive info " do
    expected = {
      "data" => {
        "__type" => {
          "name"        => "DairyProductInput",
          "description" => "Properties for finding a dairy product",
          "kind"        => "INPUT_OBJECT",
          "inputFields" => [
            {
              "name" => "source", "type" => {"kind" => "NON_NULL", "name" => nil}, "defaultValue" => nil,
              "description" => "Where it came from",
            },
            {
              "name" => "originDairy",
              "type" => {
                "kind" => "SCALAR", "name" => "String",
              },
              "defaultValue" => "\"Sugar Hollow Dairy\"", "description" => "Dairy which produced it",
            },
            {
              "name" => "fatContent",
              "type" => {
                "kind" => "SCALAR",
                "name" => "Float",
              },
              "defaultValue" => "0.3",
              "description"  => "How much fat it has",
            },
            {
              "name" => "organic",
              "type" => {
                "kind" => "SCALAR",
                "name" => "Boolean",
              },
              "defaultValue" => "false",
              "description"  => nil,
            },
            {
              "name" => "order_by",
              "type" => {
                "kind" => "INPUT_OBJECT",
                "name" => "ResourceOrderType",
              },
              "defaultValue" => "{direction: \"ASC\"}",
              "description"  => nil,
            },
          ],
        },
      },
    }
    result.should eq expected
  end
end
