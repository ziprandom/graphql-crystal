# frozen_string_literal: true
require "../../spec_helper"
require "benchmark"

describe GraphQl::Language::Parser do
  subject = GraphQl::Language::Parser.new

  describe "anonymous fragment extension" do

    query_strings = [
      %{
        fragment on NestedType @or(something: "ok") {
          anotherNestedField
        }
      },
      %{
        query getSchema {
          __schema {
            types { name }
            queryType { fields { name }}
            mutationType { fields { name }}
          }
        }
      },
      %{
        query HeroNameAndFriends($episode: Episode) {
          hero(episode: $episode) {
            name
            friends {
              name
            }
          }
        }
      },
      %{
        query Hero($episode: Episode, $withFriends: Boolean!) {
          hero(episode: $episode) {
            name
            friends @include(if: $withFriends) {
              name
            }
          }
        }
      },
      %{
        mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
          createReview(episode: $ep, review: $review) {
            stars
            commentary
          }
        }
      },
      %{query HeroForEpisode($ep: Episode!) {
          hero(episode: $ep) {
            name
            ... on Droid {
              primaryFunction
            }
                   ... on Human {
              height
            }
          }
        }
      },
      %{
        query HeroForEpisode($ep: Episode!) {
          hero(episode: $ep) {
            name
            ... on Droid {
              primaryFunction
            }
                   ... on Human {
              height
            }
          }
        }
      },
      %{
        {
          search(text: "an") {
            __typename
            ... on Human {
              name
            }
            ... on Droid {
              name
            }
            ... on Starship {
              name
            }
          }
        }
      },
      %{
        type Starship {
          id: ID!
          name: String!
          length(unit: LengthUnit = METER): Float
        }
      }
    ];

    it "parses different graphql docs" do
      query_strings.each do |query_string|
        # pp query_tokens.map { |t| {name: t.value, type: t.type} }
        document = subject.parse GraphQl::Language::Lexer.lex(query_string)
      end
    end

    pending "parses the Dummy Schema" do
      document = subject.parse g
    end

    pending "creates an anonymous fragment definition" do
      assert fragment.is_a?(GraphQL::Language::Nodes::FragmentDefinition)
      assert_equal nil, fragment.name
      assert_equal 1, fragment.selections.length
      assert_equal "NestedType", fragment.type.name
      assert_equal 1, fragment.directives.length
      assert_equal [2, 7], fragment.position
    end
  end

  pending "parses empty arguments" do
    strings = [
      "{ field { inner } }",
      "{ field() { inner }}",
    ]
    strings.each do |query_str|
      doc = subject.parse(query_str)
      field = doc.definitions.first.selections.first
      assert_equal 0, field.arguments.length
      assert_equal 1, field.selections.length
    end
  end

  pending "parses the test schema" do
    schema = Dummy::Schema
    schema_string = GraphQL::Schema::Printer.print_schema(schema)
    document = subject.parse(schema_string)
    assert_equal schema_string, document.to_query_string
  end
end
