require "../../src/graphql-crystal"
require "./star_wars_data"

class Character
  field :id, GraphQL::StringType, "The id of the character."
  field :name, GraphQL::StringType, "The name of the character."
  field :friends, [Character], "The friends of the character or an empty list\
                                                                if the have none." do
    Characters.select { |c| self.friends.includes? c.id }
  end
  field :appears_in, [GraphQL::StringType], "Which movies they appear in."
  field :secret_backstory, GraphQL::StringType, "All secrets about their past." do
    raise "the secret backstory is secret ..."
  end
end

class Human
  field :home_planet, GraphQL::StringType, "the home planet of the human, or null if unknown."
end

class Droid
  field :primary_function, GraphQL::StringType, "The primary function of the droid."
end

module QueryType
  include GraphQL::ObjectType

  field :hero, Character, "", {
          episode: {
            description: "If omitted, returns the hero of the whole saga. If \
                          provided, returns the hero of that particular episode.",
            type: GraphQL::StringType
          }
        } do
    if (args["episode"]? == 5)
      Characters.find(&.id.==("1000"))
    else
      Characters.find(&.id.==("2001"))
    end
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

# StarWarsSchema.execute("{ human(id: \"1001\") { id, name }}")
# StarWarsSchema.execute("{ droid(id: \"2001\") { id, name }}")
# StarWarsSchema.execute("{ hero(episode: \"NEWHOPE\") { id, name, appears_in, friends { name } } }")

query_string = %{

  {
    c3po: droid(id: "2000") {
      ...droidFragment
    }

    luke: human(id: "1000") {
      ...humanFragment
    }
  }

  fragment humanFragment on Human {
    name
    appears_in
    home_planet
  }

  fragment droidFragment on Droid {
    name
    appears_in
    primary_function
  }
}

puts StarWarsSchema.execute(query_string).to_pretty_json
