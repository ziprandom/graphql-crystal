# coding: utf-8
# frozen_string_literal: true
require "../../spec_helper"

class GraphQL::Language::Parser
  def self.parse(prog : String, options = NamedTuple.new)
    parse(GraphQL::Language::Lexer.lex(prog), options).as(GraphQL::Language::Document)
  end
end

def clean_string(string)
  string.gsub(/^  /m, "")
        .gsub(/#[^\n]*\n/m, "\n")
        .gsub(/[\n\s]+/m, "\n").strip
end

describe GraphQL::Language::Generation do
  query_string = %{
    query getStuff($someVar: Int = 1, $anotherVar: [String!], $skipNested: Boolean! = false) @skip(if: false) {
      myField: someField(someArg: $someVar, ok: 1.4) @skip(if: $anotherVar) @thing(or: "Whatever")
      anotherField(someArg: [1, 2, 3]) {
        nestedField
        ...moreNestedFields @skip(if: $skipNested)
      }
      ... on OtherType @include(unless: false) {
        field(arg: [{key: "value", anotherKey: 0.9, anotherAnotherKey: WHATEVER}])
        anotherField
      }
      ... {
        id
      }
    }

    fragment moreNestedFields on NestedType @or(something: "ok") {
      anotherNestedField
    }
  }

  document = GraphQL::Language::Parser.parse(query_string)
  describe ".generate" do
    it "should work" do
      document = GraphQL::Language::Parser.parse query_string
      document.to_query_string.gsub(/\s+/, " ").strip.should eq query_string.gsub(/\s+/, " ").strip
    end

    it "generates query string" do
      document.to_query_string.gsub(/\s+/, " ").strip.should eq query_string.gsub(/\s+/, " ").strip
    end

    it "inputs" do
      query_string = <<-query
        query {
          field(null_value: null, null_in_array: [1, null, 3], int: 3, float: 4.7e-24, bool: false, string: "☀︎🏆\\n escaped \\" unicode ¶ /", enum: ENUM_NAME, array: [7, 8, 9], object: {a: [1, 2, 3], b: {c: "4"}}, unicode_bom: "\xef\xbb\xbfquery")
        }
      query
      document = GraphQL::Language::Parser.parse(query_string)

      it "generate" do
        document.to_query_string.gsub(/(\s+|\n)/, " ").should eq query_string.gsub(/(\s+|\n)/, " ").strip
      end
    end

    describe "schema" do
      describe "schema with convention names for root types" do
        query_string = <<-schema
          schema {
            query: Query
            mutation: Mutation
            subscription: Subscription
          }
        schema

        document = GraphQL::Language::Parser.parse(query_string)

        it "omits schema definition" do
          document.to_query_string.should_not eq /schema/
        end
      end

      it "schema with custom query root name" do
        query_string = <<-schema
          schema {
            query: MyQuery
            mutation: Mutation
            subscription: Subscription
          }
        schema

        document = GraphQL::Language::Parser.parse(query_string)

        it "includes schema definition" do
          document.to_query_string.should eq query_string.gsub(/^  /m, "").strip
        end
      end

      describe "schema with custom mutation root name" do
        query_string = <<-schema
          schema {
            query: Query
            mutation: MyMutation
            subscription: Subscription
          }
        schema

        document = GraphQL::Language::Parser.parse(query_string)

        it "includes schema definition" do
          document.to_query_string.should eq query_string.gsub(/^  /m, "").strip
        end
      end

      it "schema with custom subscription root name" do
        query_string = <<-schema
          schema {
            query: Query
            mutation: Mutation
            subscription: MySubscription
          }
        schema

        document = GraphQL::Language::Parser.parse(query_string)

        it "includes schema definition" do
          document.to_query_string.should eq query_string.gsub(/^  /m, "").strip
        end
      end

      describe "full featured schema" do
        # From: https://github.com/graphql/graphql-js/blob/bc96406ab44453a120da25a0bd6e2b0237119ddf/src/language/__tests__/schema-kitchen-sink.graphql
        query_string = <<-schema
          schema {
            query: QueryType
            mutation: MutationType
          }

          # Union description
          union AnnotatedUnion @onUnion = A | B

          type Foo implements Bar {
            one: Type
            two(argument: InputType!): Type
            three(argument: InputType, other: String): Int
            four(argument: String = "string"): String
            five(argument: [String] = ["string", "string"]): String
            six(argument: InputType = {key: "value"}): Type
          }

          # Scalar description
          scalar CustomScalar

          type AnnotatedObject @onObject(arg: "value") {
            annotatedField(arg: Type = "default" @onArg): Type @onField
          }

          interface Bar {
            one: Type
            four(argument: String = "string"): String
          }

          # Enum description
          enum Site {
            # Enum value description
            DESKTOP
            MOBILE
          }

          interface AnnotatedInterface @onInterface {
            annotatedField(arg: Type @onArg): Type @onField
          }

          union Feed = Story | Article | Advert

          # Input description
          input InputType {
            key: String!
            answer: Int = 42
          }

          union AnnotatedUnion @onUnion = A | B

          scalar CustomScalar

          # Directive description
          directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

          scalar AnnotatedScalar @onScalar

          enum Site {
            DESKTOP
            MOBILE
          }

          enum AnnotatedEnum @onEnum {
            ANNOTATED_VALUE @onEnumValue
            OTHER_VALUE
          }

          input InputType {
            key: String!
            answer: Int = 42
          }

          input AnnotatedInput @onInputObjectType {
            annotatedField: Type @onField
          }

          directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

          directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
        schema

        document = GraphQL::Language::Parser.parse(query_string)

        it "generate" do
          clean_string(
            document.to_query_string
          ).should eq clean_string(
            query_string
          )
        end

        it "generate argument default to null" do
          query_string = <<-schema
            type Foo {
              one(argument: String = null): Type
              two(argument: Color = Red): Type
            }
          schema

          expected = <<-schema
            type Foo {
              one(argument: String): Type
              two(argument: Color = Red): Type
            }
          schema

          document = GraphQL::Language::Parser.parse(query_string)

          clean_string(
            document.to_query_string
          ).should eq clean_string(
            expected
          )
        end

        it "doesn't mutate the document" do
          document.to_query_string.should eq document.to_query_string
        end
      end
    end
  end
end
