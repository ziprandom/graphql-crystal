require "../../src/graphql-crystal"
require "./star_wars_data"

class Character
  field :id, GraphQL::StringType, "The id of the character."
  field :name, GraphQL::StringType, "The name of the character."
  field :friends, [Character], "The friends of the character or an empty list\
                                                                if the have none." do
    Characters.select { |c| self.friends.includes? c.id }
  end

  field :appearsIn, [EpisodeEnumType], "Which movies they appear in." { self.appears_in }
  field :secretBackstory, GraphQL::StringType, "All secrets about their past." do
    raise "secretBackstory is secret."
  end
end

class Human
  field :homePlanet, GraphQL::StringType, "the home planet of the human, or null if unknown." { self.home_planet }
end

class Droid
  field :primaryFunction, GraphQL::StringType, "The primary function of the droid." { self.primary_function }
end


STARWARS_SCHEMA_DEFINITION = <<-schema_string
  schema {
    query: QueryType
  }

  enum Episode {
    NEWHOPE
    EMPIRE
    JEDI
  }

  type QueryType {
    hero(episode: Episode): Character
    humans(ids: [String]): [Human]
    human(id: String!): Human
    droid(id: String!): Droid
  }

  interface Character {
    id: String
    name: String
    friends: [Character]
    appearsIn: [Episode]
    secretBackstory: String
  }

  type Human implements Character {
    homePlanet: String
  }

  type Droid implements Character {
    primaryFunction: String
  }

schema_string

StarWarsSchema = GraphQL::Schema.from_schema(STARWARS_SCHEMA_DEFINITION).resolve do

  query :hero do |args|
    if (args["episode"]? == "EMPIRE")
      Characters.find(&.id.==("1000"))
    else
      Characters.find(&.id.==("2001"))
    end
  end

  query :humans do |args|
    args["ids"].as(Array).map { |i| Characters.find( &.id.==(i) ) }
  end

  query :human do |args|
    Characters.select( &.is_a?(Human) ).find( &.id.==(args["id"]) )
  end

  query :droid do |args|
    Characters.select(&.is_a?(Droid)).find( &.id.==(args["id"]))
  end

end
