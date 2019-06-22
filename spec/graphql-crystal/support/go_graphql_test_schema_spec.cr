require "../../spec_helper"

describe GO_GRAPHQL_TEST_SCHEMA do
  it "parses the complex query that was used by the go-graphql benchmark" do
    query = %{
      query Example($size: Int) {
        A,
        b,
        x: c
        ...c
        f
        ...on DataType {
          Pic(size: $size)
          promise {
            A
          }
        }
        deep {
          A
          b
          c
          deeper {
            A
            b
          }
        }
      }
      fragment c on DataType {
        d
        e
      }
    }

    expected = JSON.parse(
      %{
         {
           "data": {
             "A": "Apple",
             "b": "Banana",
             "x": "Cookie",
             "d": "Donut",
             "e": "Egg",
             "f": "Fish",
             "Pic": "Pic of size: 50",
             "promise": {
                 "A": "Apple"
               },
             "deep": {
               "A": "Already Been Done",
               "b": "Boring",
               "c": [
                     "Contrived",
                     null,
                     "Confusing"
                   ],
               "deeper": [{
                            "A": "Already Been Done",
                            "b": "Boring"
                          },{
                            "A": "Already Been Done",
                            "b": "Boring"
                          }]
             }
           }
         }
      }).as_h
    result = GO_GRAPHQL_TEST_SCHEMA.execute(query, ({"size" => 50}))
    result.should eq expected
  end
end
