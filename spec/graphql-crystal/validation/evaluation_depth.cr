require "../../spec_helper"
schema_string = <<-schema_string
  schema {
    query: QueryType
  }

  type QueryType {
    firstElement: ListElement
  }

  type ListElement {
    index: Int
    next: ListElement
  }
schema_string

class ListElement
  include GraphQL::ObjectType
  def initialize(@index = 0); end

  field :index { @index }
  field :next { self.class.new(@index + 1) }
end

describe GraphQL::Schema do
  describe "Execution Depth Constraint" do
    test_schema = GraphQL::Schema.from_schema(schema_string).resolve do
      max_depth 5
      query :firstElement { ListElement.new }
    end

    it "allows queries that don't surpass the set max depth for the schema" do
      test_schema.execute(%< { firstElement { index } } >).should eq ({
        "data" => {
          "firstElement" => {
            "index" => 0
          }
        }
      })

      test_schema
        .execute(%< { firstElement { next { next { index } } } } >)
        .should eq ({
                      "data" => {
                        "firstElement" => {
                          "next" => {
                            "next" => {
                              "index" => 2
                            }
                          }
                        }
                      }
                    })
      test_schema
        .execute(%< { firstElement { next { next { next { index } } } } } >)
        .should eq ({
                      "data" => {
                        "firstElement" => {
                          "next" => {
                            "next" => {
                              "next" => {
                                "index" => 3
                              }
                            }
                          }
                        }
                      }
                    })

    end

    it "throws an error when the max execution depth is reached" do
      test_schema
        .execute(%< { firstElement { next { next { next { next { index } } } } } } >)
        .should eq ({
                      "data" => {
                        "firstElement" => {
                          "next" => {
                            "next" => {
                              "next" => {
                                "next" => nil
                              }
                            }
                          }
                        }
                      },
                      "errors" => [
                        {
                          "message" => "max execution depth reached",
                          "path" => [
                            "firstElement", "next", "next", "next", "next"
                          ]
                        }
                      ]
                    })
    end
  end
end
