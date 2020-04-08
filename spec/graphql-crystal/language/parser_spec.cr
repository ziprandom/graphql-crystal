# frozen_string_literal: true
require "../../spec_helper"

class GraphQL::Language::Parser
  def self.parse(prog : String, options = {lookahead: false})
    GraphQL::Language::Parser.new(GraphQL::Language::Lexer.new).parse(prog).as(GraphQL::Language::Document)
  end
end

describe GraphQL::Language::Parser do
  subject = GraphQL::Language::Parser

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
      },
      %{
        # a spaceship
        # that flies through
        # space
        type Starship {
          id: ID!
          # the name
          # of that starship
          name: String!
          length(
            # the desired unit
            unit: LengthUnit = METER
          ): Float
        }
      },
    ]

    query_strings.each do |query_string|
      it "parses different graphql docs: #{query_string}" do
        document = subject.parse(query_string)
        (document.definitions.size > 0).should eq true
      end
    end

    pending "parses the Dummy Schema" do
      document = subject.parse g
    end

    it "creates an anonymous fragment definition" do
      document = subject.parse query_strings[0]

      fragment = document.definitions.first
      fragment.is_a?(GraphQL::Language::FragmentDefinition).should eq true

      if (fragment.is_a?(GraphQL::Language::FragmentDefinition))
        fragment.name.should eq nil
        fragment.selections.size.should eq 1
        fragment.type.as(GraphQL::Language::TypeName).name.should eq "NestedType"
        fragment.directives.size.should eq 1
        # fragment.position.should eq [2, 7]
      end
    end
  end

  it "parses empty arguments" do
    strings = [
      "{ field { inner } }",
    ]

    strings.each do |query_str|
      doc = subject.parse(query_str)
      field = doc.definitions
        .first.as(GraphQL::Language::OperationDefinition)
        .selections.first.as(GraphQL::Language::Field)
      field.arguments.size.should eq 0
      field.selections.size.should eq 1
    end
  end

  pending "parses the test schema" do
    schema = Dummy::Schema
    schema_string = GraphQL::Schema::Printer.print_schema(schema)
    document = subject.parse(schema_string)
    assert_equal schema_string, document.to_query_string
  end
end
