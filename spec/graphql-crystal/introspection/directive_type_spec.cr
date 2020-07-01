require "../../spec_helper"

describe "GraphQL::Introspection::DirectiveType" do
  query_string = <<-query_string
    query getDirectives {
      __schema {
        directives {
          name,
          args { name, type { kind, name, ofType { name } } },
          locations
          onField
          onFragment
          onOperation
        }
      }
    }
  query_string
  result = Dummy::SCHEMA.execute(query_string)

  it "shows directive info " do
    expected = {"data" => {
      "__schema" => {
        "directives" => [
          {
            "name" => "include",
            "args" => [
              {"name" => "if", "type" => {"kind" => "NON_NULL", "name" => nil, "ofType" => {"name" => "Boolean"}}},
            ],
            "locations"   => ["FIELD", "FRAGMENT_SPREAD", "INLINE_FRAGMENT"],
            "onField"     => true,
            "onFragment"  => true,
            "onOperation" => false,
          },
          {
            "name" => "skip",
            "args" => [
              {"name" => "if", "type" => {"kind" => "NON_NULL", "name" => nil, "ofType" => {"name" => "Boolean"}}},
            ],
            "locations"   => ["FIELD", "FRAGMENT_SPREAD", "INLINE_FRAGMENT"],
            "onField"     => true,
            "onFragment"  => true,
            "onOperation" => false,
          },
          {
            "name" => "deprecated",
            "args" => [
              {"name" => "reason", "type" => {"kind" => "SCALAR", "name" => "String", "ofType" => nil}},
            ],
            "locations"   => ["FIELD_DEFINITION", "ENUM_VALUE"],
            "onField"     => false,
            "onFragment"  => false,
            "onOperation" => false,
          },
        ],
      },
    }}
    result.should eq expected
  end
end
