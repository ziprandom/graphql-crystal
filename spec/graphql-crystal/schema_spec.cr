require "../spec_helper"

describe GraphQL::Schema do

  describe "resolve" do

    it "answers a simple field request" do
      TestSchema.execute("{ user(id: 0) { name } }").should eq({ "user" => { "name" => "otto neverthere" }})
    end

    it "answers a simple field request for several fields" do
      TestSchema.execute(
        "{ user(id: 0) { id, name } }"
      ).should eq({ "user" => { "id" => 0, "name" => "otto neverthere" }})
    end

    it "answers a simple field request for a nested resource" do
      TestSchema.execute(
        "{ user(id: 0) { id, address { city } } }"
      ).should eq({
                    "user" => {
                      "id" => 0,
                      "address" => {
                        "city" => "London"
                      }
                    }
                  })
    end

    it "answers a more deep request for a list resource" do
      TestSchema.execute(
        "{ user(id: 0) { id, friends { id, name } } }"
      ).should eq({
                    "user" => {
                      "id" => 0,
                      "friends" => [
                        { "id" => 2, "name" => "wilma nunca" },
                        { "id" => 1, "name" => "jennifer nonone" }
                      ]
                    }
                  })
    end

    it "answers a request for a field with a custom resolve callback" do
      TestSchema.execute(
        "{ user(id: 0) { full_address } }"
      ).should eq({
                    "user" => {
                      "full_address" => "otto neverthere\n---------------\n11 Downing Street\n3231 London"
                    }
                  })
    end

    it "raises an error if we request a field that hast not been defined" do
      bad_query_string = %{
        {
          car(name: "toyota") {
            id, year
          }
        }
      }
      expect_raises(Exception, "unknown fields: car") do
        TestSchema.execute(bad_query_string)
      end
    end

    it "raises an error if we request a field with an argument that hasn't been defined" do
      bad_query_string = %{
        {
          user(name: "henry") {
            id, name
          }
        }
      }
      expect_raises(Exception, "name isn't allowed for queries on the user field") do
        TestSchema.execute(bad_query_string)
      end
    end

    it "raises an error if we request a field with defined argument using a wrong type" do
      bad_query_string = %{
        {
          user(id: "henry") {
            id, name
          }
        }
      }
      expect_raises(
        Exception,
        %{argument "id" is expected to be of Type: "IDType", "henry" has been rejected}
      ) do
        TestSchema.execute(bad_query_string)
      end
    end

  end
end
