# use compile time finalized  version
require "../src/graphql-crystal"
require "./lib/libragphqlparserC"
require "benchmark"

schema_string = <<-schema_string
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

query_string = <<-query_string
{
  firstUser: user(id: 0) {
    ... userFields
  },
  secondUser: user(id: 1) {
    ... userFields
  }
}
fragment userFields on User {
  id, name
}
query_string

puts GraphQL::Language::Parser.parse(
  GraphQL::Language::Lexer.lex(schema_string)
).as(GraphQL::Language::Document).to_query_string
puts GraphQL::Language::Parser.parse(
  GraphQL::Language::Lexer.lex(query_string)
).as(GraphQL::Language::Document).to_query_string

# Parse the Schema to a Document ASTNode
Benchmark.ips(warmup: 4, calculation: 10) do |x|
  x.report("SCHEMA String: c implementation from facebook: ") {
    GraphQLParser.parse_string(schema_string, nil)
  }

  x.report("SCHEMA String: cltk based implementation: ") {
    GraphQL::Language::Parser.parse(
      GraphQL::Language::Lexer.lex(schema_string)
    )
  }

  x.report("SCHEMA String: dotnet based implementation: ") {
    GraphQL::WParser.new(
      GraphQL::WLexer.new
    ).parse(schema_string)
  }
end

# Parse the Schema to a Document ASTNode
Benchmark.ips(warmup: 4, calculation: 10) do |x|
  x.report("QUERY String: c implementation from facebook: ") {
    GraphQLParser.parse_string(query_string, nil)
  }

  x.report("QUERY String: cltk based implementation: ") {
    GraphQL::Language::Parser.parse(
      GraphQL::Language::Lexer.lex(query_string)
    )
  }

  x.report("QUERY String: dotnet based implementation: ") {
    GraphQL::WParser.new(
      GraphQL::WLexer.new
    ).parse(query_string)
  }
end
