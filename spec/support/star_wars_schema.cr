require "../../src/graphql-crystal"
require "./star_wars_data"

class EpisodeEnumType < GraphQL::EnumType(EpisodeEnum); end

class Character
  field :id, GraphQL::StringType, "The id of the character."
  field :name, GraphQL::StringType, "The name of the character."
  field :friends, [Character], "The friends of the character or an empty list\
                                                                if the have none." do
    Characters.select { |c| self.friends.includes? c.id }
  end
  field :appearsIn, [EpisodeEnumType], "Which movies they appear in." { self.appears_in }
  field :secretBackstory, GraphQL::StringType, "All secrets about their past." do
    raise "the secret backstory is secret ..."
  end
end

class Human
  field :homePlanet, GraphQL::StringType, "the home planet of the human, or null if unknown." { self.home_planet }
end

class Droid
  field :primaryFunction, GraphQL::StringType, "The primary function of the droid." { self.primary_function }
end

module QueryType
  include GraphQL::ObjectType

  field :hero, Character, "", {
          episode: {
            description: "If omitted, returns the hero of the whole saga. If \
                          provided, returns the hero of that particular episode.",
            type: EpisodeEnumType
          }
        } do
    if (args["episode"]? == 5)
      Characters.find(&.id.==("1000"))
    else
      Characters.find(&.id.==("2001"))
    end
  end

  field :humans, [Human], "", {
    ids: {
      description: "a list of ids",
      type: [GraphQL::StringType]
    }
  } do
    args["ids"].as(Array).map { |i| Characters.find( &.id.==(i) ) }
  end

  field :human, Human, "", {
          id: {
            description: "id of the human",
            type: GraphQL::StringType
          }
        } do
    Characters.select(&.is_a?(Human)).find( &.id.==(args["id"]))
  end

  field :droid, Droid, "", {
          id: {
            description: "id of the droid",
            type: GraphQL::StringType
          }
        } do
    Characters.select(&.is_a?(Droid)).find( &.id.==(args["id"]))
  end

end

module StarWarsSchema
  extend GraphQL::Schema
  query QueryType
end
