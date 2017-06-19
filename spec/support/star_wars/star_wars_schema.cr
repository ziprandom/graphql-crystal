require "./star_wars_data"

abstract class Character
  field :id
  field :name
  field :friends  do
    Characters.select { |c| self.friends.includes? c.id }
  end

  field :appearsIn { self.appears_in }
  field :secretBackstory do
    raise "secretBackstory is secret."
  end
end

class Human
  field :homePlanet { self.home_planet }
end

class Droid
  field :primaryFunction { self.primary_function }
end

STARWARS_SCHEMA_DEFINITION = <<-schema_string
  schema {
    query: QueryType
  }

  # One of the Movies
  enum Episode {
    # Episode IV: A New Hope
    NEWHOPE
    # Episode V: The Empire Strikes Back
    EMPIRE
    # Episode VI: Return of the Jedi
    JEDI
  }

  type QueryType {
    # Get the main hero of an episode
    hero(episode: Episode): Character
    # Get Humans by Id
    humans(ids: [String]): [Human]
    # Get a Human by Id
    human(id: String!): Human
    # Get a Droid by Id
    droid(id: String!): Droid
  }

  # A Star Wars Character
  interface Character {
    # The id of the character
    id: String

    # The name of the character
    name: String

    # The friends of the character or
    # an empty list if the have none
    friends: [Character]
    # Which movies they appear in
    appearsIn: [Episode]
    # All secrets about their past
    secretBackstory: String
  }

  # A humanoid Star Wars Character
  type Human implements Character {
    # the home planet of the
    # human, or null if unknown
    homePlanet: String
  }

  # A robotic Star Wars Character
  type Droid implements Character {
    # The primary function of the droid
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
