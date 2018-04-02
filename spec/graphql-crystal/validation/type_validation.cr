require "../../spec_helper"
SCHEMA_STRING = <<-schema_string
  schema {
    query: QueryType
  }

  type QueryType {
    test_nonnull(arg: String!): String
    test_list(arg: [String]): String
    test_scalars(id: ID!, int: Int, float: Float, string: String, bool: Boolean) : String
  }

  enum TestEnum {
    ValueA
    ValueB
    ValueC
  }

  input TestInput {
    id: ID!
    title: String!
    body: String
  }

  union TestUnion = TestEnum | Int

schema_string

TEST_SCHEMA = GraphQL::Schema.from_schema SCHEMA_STRING

VALUES = {
  id:                      23,
  uuid:                    "10526f6b-76a3-43cf-bad3-a521954a568f",
  string:                  "Hallo",
  int:                     32,
  float:                   32.3,
  bool:                    true,
  bool2:                   false,
  list:                    ["Hallo", "Hey"],
  mixed_list:              [23, "hey", 23.2],
  enum:                    GraphQL::Language::AEnum.new(name: "ValueA"),
  null:                    nil,
  input_object:            {"id" => "10526f6b-76a3-43cf-bad3-a521954a568f", "title" => "my title", "body" => "a body for this"},
  input_object_missing:    {"title" => "my title", "body" => "a body for this"},
  input_object_superfluos: {
    "id"       => "10526f6b-76a3-43cf-bad3-a521954a568f",
    "title"    => "my title",
    "subtitle" => "what remains to be said",
    "body"     => "a body for this",
  },
}

TYPE_VALIDATION = GraphQL::TypeValidation.new TEST_SCHEMA.types

def reject_other_than(type, leave_out)
  leave_out = (
    leave_out.is_a?(Array) ? leave_out : [leave_out]
  ).map { |name| VALUES[name] }
  VALUES.to_a.reject { |(_, val)| leave_out.includes?(val) }
             .each do |(_, val)|
    it "rejects '#{val.inspect}'" do
      TYPE_VALIDATION.accepts?(type, val).should eq false
    end
  end
end

describe GraphQL::TypeValidation do
  describe GraphQL::Language::EnumTypeDefinition do
    type = TEST_SCHEMA.types["TestEnum"]

    it "accepts a string representing a valid enum value" do
      TYPE_VALIDATION.accepts?(type, VALUES[:enum].name).should eq true
    end

    it "rejects a string representing an invalid enum value" do
      TYPE_VALIDATION.accepts?(type, GraphQL::Language::AEnum.new(name: "ValueD")).should eq false
    end

    reject_other_than(type, [:enum, :null])
  end

  describe GraphQL::Language::UnionTypeDefinition do
    type = TEST_SCHEMA.types["TestUnion"]

    it "accepts a string representing a valid enum value" do
      TYPE_VALIDATION.accepts?(type, VALUES[:enum]).should eq true
    end

    it "accepts a string representing a valid enum value" do
      TYPE_VALIDATION.accepts?(type, VALUES[:int]).should eq true
    end

    reject_other_than(type, [:enum, :int, :id, :null])
  end

  describe GraphQL::Language::NonNullType do
    type = TEST_SCHEMA.types["QueryType"].as(GraphQL::Language::ObjectTypeDefinition)
      .fields.find(&.name.==("test_nonnull")).not_nil!.arguments.first.type

    it "accepts a String (it's of_type & not null)" do
      TYPE_VALIDATION.accepts?(type, "Hello").should eq true
    end

    it "rejects nil" do
      TYPE_VALIDATION.accepts?(type, nil).should eq false
    end
  end

  describe GraphQL::Language::ListType do
    type = TEST_SCHEMA.types["QueryType"].as(GraphQL::Language::ObjectTypeDefinition)
      .fields.find(&.name.==("test_list")).not_nil!.arguments.first.type

    it "accepts an array of String" do
      TYPE_VALIDATION.accepts?(type, VALUES[:list]).should eq true
    end

    reject_other_than(type, [:list, :null])
  end

  describe GraphQL::Language::ScalarTypeDefinition do
    types = TEST_SCHEMA.types["QueryType"].as(GraphQL::Language::ObjectTypeDefinition)
      .fields.find(&.name.==("test_scalars")).not_nil!.arguments.map &.type

    describe "ID" do
      type = types.first

      it "accepts a numeric id" do
        TYPE_VALIDATION.accepts?(type, VALUES[:id]).should eq true
      end

      it "accepts a uuid" do
        TYPE_VALIDATION.accepts?(type, VALUES[:uuid]).should eq true
      end

      reject_other_than(type, [:id, :uuid, :string, :int, :null])
    end
    describe "Int" do
      type = types[1]

      it "accepts an integer" do
        TYPE_VALIDATION.accepts?(type, VALUES[:int]).should eq true
      end

      reject_other_than(type, [:id, :int, :null])
    end

    describe "Float" do
      type = types[2]

      it "accepts a float" do
        TYPE_VALIDATION.accepts?(type, VALUES[:float]).should eq true
      end

      it "accepts an integer" do
        TYPE_VALIDATION.accepts?(type, VALUES[:int]).should eq true
      end

      reject_other_than(type, [:float, :id, :int, :null])
    end

    describe "String" do
      type = types[3]

      it "accepts a string" do
        TYPE_VALIDATION.accepts?(type, VALUES[:string]).should eq true
      end

      reject_other_than(type, [:string, :uuid, :null])
    end

    describe "Boolean" do
      type = types[4]

      it "accepts true" do
        TYPE_VALIDATION.accepts?(type, VALUES[:bool]).should eq true
      end

      it "accepts false" do
        TYPE_VALIDATION.accepts?(type, VALUES[:bool2]).should eq true
      end

      reject_other_than(type, [:bool, :bool2, :null])
    end
  end

  describe GraphQL::Language::InputObjectTypeDefinition do
    type = TEST_SCHEMA.types["TestInput"]

    it "accepts a hash of the expected structure" do
      TYPE_VALIDATION.accepts?(type, VALUES[:input_object]).should eq true
    end

    reject_other_than(type, [:input_object, :null])
  end
end
