# coding: utf-8
require "../spec_helper"

describe GraphQL::Directive do
  describe GraphQL::Directives::IsDeprecated do
    describe "on FieldDefinition" do
      query_string = %{
        {
          __type(name: "User") {
            fields(includeDeprecated: true) {
              name
              isDeprecated
              deprecationReason
            }
          }
        }
      }

      it "indicates the defined deprecation" do
        TestSchema::Schema
          .execute(query_string)
          .should eq({
          "data" => {
            "__type" => {
              "fields" => [
                {
                  "name"              => "address",
                  "isDeprecated"      => false,
                  "deprecationReason" => nil,
                }, {
                "name"              => "friends",
                "isDeprecated"      => false,
                "deprecationReason" => nil,
              }, {
                "name"              => "full_address",
                "isDeprecated"      => false,
                "deprecationReason" => nil,
              }, {
                "name"              => "id",
                "isDeprecated"      => false,
                "deprecationReason" => nil,
              }, {
                "name"              => "name",
                "isDeprecated"      => true,
                "deprecationReason" => "for no apparent Reason",
              },
              ],
            },
          },
        })
      end
    end

    describe "on EnumValue" do
      query_string = %{
        {
          __type(name: "City") {
            name
            enumValues {
              name
              isDeprecated
              deprecationReason
            }
          }
        }
      }

      it "indicates the defined deprecation" do
        TestSchema::Schema
          .execute(query_string)
          .should eq({
          "data" => {
            "__type" => {
              "name"       => "City",
              "enumValues" => [
                {
                  "name" => "London", "isDeprecated" => false,
                  "deprecationReason" => nil,
                }, {
                "name"              => "Miami",
                "isDeprecated"      => true,
                "deprecationReason" => "is not a capital",
              }, {
                "name"              => "CABA",
                "isDeprecated"      => false,
                "deprecationReason" => nil,
              }, {
                "name"              => "Istanbul",
                "isDeprecated"      => false,
                "deprecationReason" => nil,
              },
              ],
            },
          },
        })
      end
    end
  end

  describe GraphQL::Directives::IncludeDirective do
    describe "on Field" do
      query_string = %{
        query userQuery($withName: Boolean!) {
          user(id: 0) {
            id
            ... on User @include(if: $withName) {
              name
            }
          }
        }
      }

      it "includes if :if argument is true" do
        TestSchema::Schema
          .execute(query_string, {"withName" => true})
          .should eq({
          "data" => {
            "user" => {
              "id"   => 0,
              "name" => "otto neverthere",
            },
          },
        })
      end
      it "excludes if :if argument is false" do
        TestSchema::Schema
          .execute(query_string, {"withName" => false})
          .should eq({
          "data" => {
            "user" => {
              "id" => 0,
            },
          },
        })
      end
    end

    describe "on inline Fragment" do
      query_string = %{
        query userQuery($withName: Boolean!) {
          user(id: 0) {
            id
            ... on User @include(if: $withName) {
              name
            }
          }
        }
      }

      it "includes if :if argument is true" do
        TestSchema::Schema
          .execute(query_string, {"withName" => true})
          .should eq({
          "data" => {
            "user" => {
              "id"   => 0,
              "name" => "otto neverthere",
            },
          },
        })
      end

      it "excludes if :if argument is false" do
        TestSchema::Schema
          .execute(query_string, {"withName" => false})
          .should eq({
          "data" => {
            "user" => {
              "id" => 0,
            },
          },
        })
      end
    end

    describe "on Fragment" do
      query_string = %{
        query userQuery($withName: Boolean!) {
          user(id: 0) {
            id
            ... userName @include(if: $withName)
          }
        }
        fragment userName on User {
          name
        }
      }

      it "includes if :if argument is true" do
        TestSchema::Schema
          .execute(query_string, {"withName" => true})
          .should eq({
          "data" => {
            "user" => {
              "id"   => 0,
              "name" => "otto neverthere",
            },
          },
        })
      end

      it "excludes if :if argument is false" do
        TestSchema::Schema
          .execute(query_string, {"withName" => false})
          .should eq({
          "data" => {
            "user" => {
              "id" => 0,
            },
          },
        })
      end
    end
  end

  describe GraphQL::Directives::SkipDirective do
    describe "on Field" do
      query_string = %{
        query userQuery($skipName: Boolean!) {
          user(id: 0) {
            id
            ... on User @skip(if: $skipName) {
              name
            }
          }
        }
      }

      it "skips if :if argument is true" do
        TestSchema::Schema
          .execute(query_string, {"skipName" => true})
          .should eq({
          "data" => {
            "user" => {
              "id" => 0,
            },
          },
        })
      end
      it "includes if :if argument is false" do
        TestSchema::Schema
          .execute(query_string, {"skipName" => false})
          .should eq({
          "data" => {
            "user" => {
              "id"   => 0,
              "name" => "otto neverthere",
            },
          },
        })
      end
    end

    describe "on inline Fragment" do
      query_string = %{
        query userQuery($skipName: Boolean!) {
          user(id: 0) {
            id
            ... on User @skip(if: $skipName) {
              name
            }
          }
        }
      }

      it "skips if :if argument is true" do
        TestSchema::Schema
          .execute(query_string, {"skipName" => true})
          .should eq({
          "data" => {
            "user" => {
              "id" => 0,
            },
          },
        })
      end

      it "includes if :if argument is false" do
        TestSchema::Schema
          .execute(query_string, {"skipName" => false})
          .should eq({
          "data" => {
            "user" => {
              "id"   => 0,
              "name" => "otto neverthere",
            },
          },
        })
      end
    end

    describe "on Fragment" do
      query_string = %{
        query userQuery($skipName: Boolean!) {
          user(id: 0) {
            id
            ... userName @skip(if: $skipName)
          }
        }
        fragment userName on User {
          name
        }
      }

      it "skips if :if argument is true" do
        TestSchema::Schema
          .execute(query_string, {"skipName" => true})
          .should eq({
          "data" => {
            "user" => {
              "id" => 0,
            },
          },
        })
      end

      it "includes if :if argument is false" do
        TestSchema::Schema
          .execute(query_string, {"skipName" => false})
          .should eq({
          "data" => {
            "user" => {
              "id"   => 0,
              "name" => "otto neverthere",
            },
          },
        })
      end
    end
  end
end
