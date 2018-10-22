# coding: utf-8
require "../spec_helper"

describe GraphQL::Schema do
  describe "resolve" do
    it "answers a simple field request" do
      TestSchema::Schema.execute("{ user(id: 0) { name } }").should eq({"data" => {"user" => {"name" => "otto neverthere"}}})
    end

    it "answers a simple field request for a field defined later in the inheritance chain (SpecialQuery)" do
      expected = {
        "data" => {
          "addresses" => [
            {"city" => "London"},
            {"city" => "Miami"},
            {"city" => "CABA"},
          ],
        },
      }
      TestSchema::Schema.execute("{ addresses { city } }").should eq expected
    end

    it "answers a simple field request for a field defined later in the inheritance chain (SpecialQuery)" do
      expected = {
        "data" => {
          "addresses" => [
            {"city" => "London", "street" => "Downing Street", "number" => 11},
            {"city" => "Miami", "street" => "Sunset Boulevard", "number" => 114},
          ],
        },
      }
      TestSchema::Schema.execute(%{
                           { addresses(city: [London, Miami]) { city street number } }
                         }).should eq expected
    end

    it "answers a simple field request for a field defined later in the inheritance chain (SpecialQuery)" do
      expected = {
        "data" => {
          "addresses" => [] of Nil,
        },
      }
      TestSchema::Schema.execute(%{
                           { addresses(city: [Istanbul]) { city street number } }
                         }).should eq expected
    end

    it "answers a simple field request for several fields" do
      expected = {
        "data" => {
          "user" => {
            "id" => 0, "name" => "otto neverthere",
          },
        },
      }
      TestSchema::Schema.execute(
        "{ user(id: 0) { id, name } }"
      ).should eq(expected)
    end

    it "answers a simple field request for a nested resource" do
      TestSchema::Schema.execute(
        "{ user(id: 0) { id, address { city } } }"
      ).should eq({
        "data" => {
          "user" => {
            "id"      => 0,
            "address" => {
              "city" => "London",
            },
          },
        },
      })
    end

    it "answers a more deep request for a list resource" do
      TestSchema::Schema.execute(
        "{ user(id: 0) { id, friends { id, name } } }"
      ).should eq({
        "data" => {
          "user" => {
            "id"      => 0,
            "friends" => [
              {"id" => 2, "name" => "wilma nunca"},
              {"id" => 1, "name" => "jennifer nonone"},
            ],
          },
        },
      })
    end

    it "answers a request for a field with a custom resolve callback" do
      TestSchema::Schema.execute(
        "{ user(id: 0) { full_address } }"
      ).should eq({"data" => {
        "user" => {
          "full_address" => "otto neverthere\n---------------\n11 Downing Street\n3231 London",
        },
      }})
    end

    it "answers a request for aliased fields" do
      expected = {
        "data" => {
          "firstUser" => {
            "name" => "otto neverthere",
          },
          "secondUser" => {
            "name"         => "jennifer nonone",
            "aliased_name" => "jennifer nonone",
          },
        },
      }

      TestSchema::Schema.execute(%{
                           {
                             firstUser: user(id: 0) {
                               name
                             }
                             secondUser: user(id: 1) {
                               name,
                               aliased_name: name
                             }
                           }
                         }).should eq(expected)
    end

    it "answers a request for aliased resolving a fragment definition fields" do
      expected = {
        "data" => {
          "firstUser" => {
            "id"   => 0,
            "name" => "otto neverthere",
          },
          "secondUser" => {
            "id"   => 1,
            "name" => "jennifer nonone",
          },
        },
      }

      TestSchema::Schema.execute(%{
                           {
                             firstUser: user(id: 0) {
                               ... userFields
                             },
                             secondUser: user(id: 1) {
                               ... userFields
                             }
                           }
                           fragment userFields on User {
                             id, name
                           }
                         }).should eq(expected)
    end

    it "answers a request for aliased field resolving an inline fragment definition" do
      expected = {
        "data" => {
          "firstUser" => {
            "id"   => 0,
            "name" => "otto neverthere",
          },
        },
      }

      TestSchema::Schema.execute(%{
                           {
                             firstUser: user(id: 0) {
                               ... on User {
                                 id, name
                               }
                             }
                           }
                         }).should eq(expected)
    end

    it "answers a request with nullable arg and arg ommited" do
      TestSchema::Schema.execute(
        "query getAddresses($city: [City]) { addresses(city: $city) { city } }"
      ).should eq({
        "data" => {
          "addresses" => [
            {"city" => "London"},
            {"city" => "Miami"},
            {"city" => "CABA"}
          ],
        }
      })
    end

    it "answers a request with non-nullable arg and arg provided" do
      TestSchema::Schema.execute(
        "query getAddresses($city: [City]!) { addresses(city: $city) { city } }", {
          "city" => [
            "London"
          ]
        }
      ).should eq({
        "data" => {
          "addresses" => [
            {"city" => "London"}
          ],
        }
      })
    end

    it "answers a request with non-nullable arg and arg provided with JSON::Any type" do
      TestSchema::Schema.execute(
        "query getAddresses($city: [City]!) { addresses(city: $city) { city } }", JSON.parse({
          "city" => [
            "London"
          ]
        }.to_json)
      ).should eq({
        "data" => {
          "addresses" => [
            {"city" => "London"}
          ],
        }
      })
    end

    it "raises if non-nullable args ommited" do
      TestSchema::Schema.execute(
        "query getAddresses($city: [City]!) { addresses(city: $city) { city } }"
      ).should eq({
        "data" => nil, "errors" => [{"message" => "missing variable city", "path" => [] of String}]
      })
    end

    it "raises if no inline fragment was defined for the type actually returned" do
      expected = {
        "data" => {
          "firstUser" => nil,
        },
        "errors" => [
          {
            "message" => "no selections found for this field! \
                          maybe you forgot to define an inline fragment for this type in a union?",
            "path" => ["firstUser"],
          },
        ],
      }

      TestSchema::Schema.execute(%{
                           {
                             firstUser: user(id: 0) {
                               ... on Droid {
                                 id, name
                               }
                             }
                           }
                         }).should eq expected
    end

    it "raises an error when I try to use an undefined fragment" do
      expected = {
        "data"   => nil,
        "errors" => [
          {
            "message" => "fragment \"userFieldsNonExistent\" is undefined",
            "path"    => [] of String,
          },
        ],
      }

      TestSchema::Schema.execute(%{
                           {
                             firstUser: user(id: 0) {
                               ... userFieldsNonExistent
                             }
                           }
                           fragment userFields on User {
                             id, name
                           }
                         }).should eq expected
    end

    it "raises an error if we request a field that hast not been defined" do
      bad_query_string = %{
        {
          car(name: "toyota") {
            id, year
          }
        }
      }

      expected = {
        "data" => {
          "car" => nil,
        },
        "errors" => [
          {
            "message" => "field not defined.",
            "path"    => ["car"],
          },
        ],
      }

      TestSchema::Schema.execute(bad_query_string).should eq expected
    end

    it "raises an error if we request a field with an argument that hasn't been defined" do
      bad_query_string = %{
        {
          user(name: "henry") {
            id, name
          }
        }
      }

      expected = {
        "data" => {
          "user" => nil,
        },
        "errors" => [
          {
            "message" => "Unknown argument \"name\"",
            "path"    => ["user"],
          },
        ],
      }

      TestSchema::Schema.execute(bad_query_string).should eq expected
    end

    it "raises an error if we request a field with defined argument using a wrong type" do
      bad_query_string = %{
        {
          user(id: ["henry"]) {
            id, name
          }
        }
      }

      expected = {
        "data" => {
          "user" => nil,
        },
        "errors" => [
          {
            "message" => %{argument "id" is expected to be of type: "ID!"},
            "path"    => ["user"],
          },
        ],
      }

      TestSchema::Schema.execute(bad_query_string).should eq expected
    end
  end

  describe "operationName" do
    it "multiple operations with valid operationName" do
      TestSchema::Schema.execute(
        %{
          query UserOne{ user(id: 0) { name } }
          query UserTwo{ user(id: 0) { name } }
        },
        nil,
        "UserOne"
      ).should eq({"data" => {"user" => {"name" => "otto neverthere"}}})
    end

    it "one operation ignore operationName" do
      TestSchema::Schema.execute(
        %{
          query UserOne{ user(id: 0) { name } }
        },
        nil,
        "ignored operationName"
      ).should eq({"data" => {"user" => {"name" => "otto neverthere"}}})
    end

    it "multiple operations without operationName" do
      expected = {
        "errors" => [
          {
            "message" => "Must provide a valid operation name if query contains multiple operations.",
            "path"    => [] of String,
          },
        ],
      }
      TestSchema::Schema.execute(
        %{
          query UserOne{ user(id: 0) { name } }
          query UserTwo{ user(id: 0) { name } }
        }
      ).should eq expected
    end

    it "multiple operations with invalid operationName" do
      expected = {
        "errors" => [
          {
            "message" => "Must provide a valid operation name if query contains multiple operations.",
            "path"    => [] of String,
          },
        ],
      }
      TestSchema::Schema.execute(
        %{
          query UserOne{ user(id: 0) { name } }
          query UserTwo{ user(id: 0) { name } }
        },
        nil,
        "invalid operationName"
      ).should eq expected
    end
  end
end
