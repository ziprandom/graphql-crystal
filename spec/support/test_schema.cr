# coding: utf-8
require "../../src/graphql-crystal/schema"

module TestSchema
  #
  # Model Logic
  #
  enum CityEnum
    London
    Miami
    CABA
    Istanbul
  end

  Addresses = [
    {"Downing Street", 11, CityEnum::London, 3231},
    {"Sunset Boulevard", 114, CityEnum::Miami, 123439},
    {"Avenida Santa Fé", 3042, CityEnum::CABA, 12398},
  ].map { |vars| Address.new *vars }

  Users = [
    "otto neverthere", "jennifer nonone", "wilma nunca",
  ].map_with_index do |name, idx|
    User.new idx, name, Addresses[idx]
  end

  Users[2].friends = [Users[1], Users[0]]
  Users[1].friends = [Users[2], Users[0]]
  Users[0].friends = [Users[2], Users[1]]

  class Address
    include GraphQL::ObjectType
    getter :street, :number, :city, :postal_code

    def initialize(
      @street : String, @number : Int32,
      @city : CityEnum, @postal_code : Int32
    )
    end

    field :street
    field :number
    field :city # { city.to_s }
    field :postal_code
  end

  class User
    include GraphQL::ObjectType
    getter :id, :name, :address
    property :friends

    def initialize(
      @id : Int32, @name : String,
      @address : Address,
      @friends = Array(User).new
    )
    end

    field :id
    field :name
    field :address
    field :friends
    field :full_address do
      <<-address
      #{name}
      #{name.size.times.to_a.map { "-" }.join}
      #{address.number} #{address.street}
      #{address.postal_code} #{address.city}
      address
    end
  end

  #
  # Schema Definition
  #
  SCHEMA_DEFINITION = <<-graphql_schema
     # Welcome to GraphiQL
     #
     # GraphiQL is an in-browser tool for writing, validating, and
     # testing GraphQL queries.
     #
     # Type queries into this side of the screen, and you will see intelligent
     # typeaheads aware of the current GraphQL type schema and live syntax and
     # validation errors highlighted within the text.
     #
     # GraphQL queries typically start with a "{" character. Lines that starts
     # with a # are ignored.
     #
     # An example GraphQL query might look like:
     # Welcome to GraphiQL
     #
     # GraphiQL is an in-browser tool for writing, validating, and
     # testing GraphQL queries.
     #
     # Type queries into this side of the screen, and you will see intelligent
     # typeaheads aware of the current GraphQL type schema and live syntax and
     # validation errors highlighted within the text.
     #
     # GraphQL queries typically start with a "{" character. Lines that starts
     # with a # are ignored.
     #
     # An example GraphQL query might look like:
     #
     # {
     # field(arg: "value") {
     # subField
     # }
     # }
     #
     # Keyboard shortcuts:
     #
     # Run Query: Ctrl-Enter (or press the play button above)
     #
     # Auto Complete: Ctrl-Space (or just start typing)
    schema {
      query: QueryType,
      mutation: MutationType
    }

    type QueryType {
      # A user in the system.
      user(id: ID!): User
      addresses(city: [City]): [Address]
    }

    enum City {
      London
      Miami @deprecated(reason: "is not a capital")
      CABA
      Istanbul
    }

    type User {
      id: ID!
      name: String @deprecated(reason: "for no apparent Reason")
      address: Address
      friends: [User]
      full_address: String
    }

    type Address {
      street: String
      number: Int
      city: City
      postal_code: Int
    }
  graphql_schema

  module QueryType
    include GraphQL::ObjectType
    extend self

    field :user do |args|
      Users.find &.id.==(args["id"])
    end

    field :addresses do |args|
      (cities = args["city"]?) ? Addresses.select do |address|
        cities.as(Array).includes? address.city.to_s
      end : Addresses
    end
  end

  #
  # instantiate the schema and add the RootQuery Resolver
  #
  Schema = GraphQL::Schema.from_schema(SCHEMA_DEFINITION)
  Schema.query_resolver = QueryType
end
