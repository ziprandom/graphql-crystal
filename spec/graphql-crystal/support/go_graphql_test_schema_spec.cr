require "../../spec_helper"

describe GO_GRAPHQL_TEST_SCHEMA do
  it "parses the complex query that was used by the go-graphql benchmark" do

    query = %{
      query Example($size: Int) {
	a,
	b,
	x: c
	...c
	f
	...on DataType {
	  pic(size: $size)
	  promise {
	    a
	  }
	}
	deep {
	  a
	  b
	  c
	  deeper {
	    a
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
             "a": "Apple",
             "b": "Banana",
             "x": "Cookie",
             "d": "Donut",
             "e": "Egg",
             "f": "Fish",
             "pic": "Pic of size: 50",
             "promise": {
                 "a": "Apple"
               },
             "deep": {
               "a": "Already Been Done",
               "b": "Boring",
               "c": [
                     "Contrived",
                     null,
                     "Confusing"
                   ],
               "deeper": [{
                            "a": "Already Been Done",
                            "b": "Boring"
                          },{
                            "a": "Already Been Done",
                            "b": "Boring"
                          }]
             }
           }
         }
      }).as_h
    result = GO_GRAPHQL_TEST_SCHEMA.execute(query, ({"size" => 50}) )
    result.should eq expected
  end
end
