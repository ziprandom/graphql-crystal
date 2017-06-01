# coding: utf-8
require "../spec_helper"

describe GraphQL::Directive do
  describe GraphQL::Directives::IncludeDirective do
    it "works" do
      query_string = %{
        query userQuery($withName: Boolean!) {
          user(id: 0) {
            id
            name @include(if: $withName)
          }
        }
      }

      TestSchema
        .execute(query_string, {"withName" => false})
        .should eq({
                     "data" => {
                       "user" => {
                         "id" => 0,
                         "name" => "otto neverthere"
                       }
                     }
                   })
    end
  end
end
