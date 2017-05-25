# coding: utf-8
require "../src/graphql-crystal/schema"

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
  {"Avenida Santa Fé", 3042, CityEnum::CABA, 12398}
].map { |vars| Address.new *vars }

Users = [
  "otto neverthere", "jennifer nonone", "wilma nunca"
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
        @city : CityEnum, @postal_code : Int32)
  end
  field :street, GraphQL::StringType
  field :number, GraphQL::IntType
  field :city, CityEnumType
  field :postal_code, GraphQL::IntType
end

class User
  include GraphQL::ObjectType
  getter :id, :name, :address
  property :friends
  def initialize(
        @id : Int32, @name : String,
        @address : Address,
        @friends = Array(User).new)
  end

  field :id, GraphQL::IDType
  field :name, GraphQL::StringType
  field :address, Address
  field :friends, [User]
  field :full_address, GraphQL::StringType do
    <<-address
    #{name}
    #{name.size.times.to_a.map {"-"}.join}
    #{address.number} #{address.street}
    #{address.postal_code} #{address.city}
    address
  end
end

#
# Schema Definition
#
SCHEMA_DEFINITION = <<-graphql_schema
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
    Miami
    CABA
    Istanbul
  }

  type User {
    id: ID!
    name: String
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

#
# define the root queries & mutation
#
TestSchema = GraphQL::Schema.from_schema(SCHEMA_DEFINITION).resolve do

  query :user do |args|
    Users.find &.id.==( args["id"] )
  end

  query :addresses do |args|
    (cities = args["city"]?) ?
      Addresses.select do |address|
        cities.as( Array ).includes? address.city.to_s
      end : Addresses
  end

end
