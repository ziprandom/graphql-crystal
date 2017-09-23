require "../../spec_helper"
module EvaluationDepthTest

  SCHEMA_STRING = <<-schema_string
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

  module QueryType
    include GraphQL::ObjectType
    extend self
    field :firstElement { ListElement.new }
  end

  Schema = GraphQL::Schema.from_schema(SCHEMA_STRING)
  Schema.max_depth 5
  Schema.query_resolver = QueryType

end

describe GraphQL::Schema do
  describe "Execution Depth Constraint" do

    it "allows queries that don't surpass the set max depth for the schema" do
      EvaluationDepthTest::Schema.execute(%< { firstElement { index } } >).should eq ({
        "data" => {
          "firstElement" => {
            "index" => 0
          }
        }
      })

      EvaluationDepthTest::Schema
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
      EvaluationDepthTest::Schema
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
      EvaluationDepthTest::Schema
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
