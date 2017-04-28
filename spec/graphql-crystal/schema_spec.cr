require "../spec_helper"

describe GraphQL::Schema do

  describe "resolve" do
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
