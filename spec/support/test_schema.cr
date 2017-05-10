# coding: utf-8
require "../src/graphql-crystal/schema"

enum CityEnum
  London
  Miami
  CABA
  Istanbul
end

# see https://github.com/crystal-lang/crystal/issues/4353
# for an explanation for why we don't just say:
# alias CityEnumType = GraphQL::EnumType(CityEnum)
class CityEnumType < GraphQL::EnumType(CityEnum); end

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
  extend GraphQL::ObjectType
  getter :street, :number, :city, :postal_code
  def initialize(
        @street : String, @number : Int32,
        @city : CityEnum, @postal_code : Int32)
  end
  field :street, GraphQL::StringType
  field :number, GraphQL::IntegerType
  field :city, CityEnumType
  field :postal_code, GraphQL::IntegerType
end

class User
  extend GraphQL::ObjectType
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

class Query
  include GraphQL::ObjectType
  field :user, User, "A user in the system.", {
          id: { type: GraphQL::IDType, description: "the user id to query for", default: nil }
        } do
    Users.find &.id.==( args["id"] )
  end
end

# just to make sure it keeps
# working with inheritance
class SpecialQuery < Query

  field :addresses, [Address], "an address in the system",
        {
          city: {
            type: [CityEnumType],
            description: "the city for which addresses should be returned",
            default: nil
          }
        } do
    (cities = args["city"]?) ?
      Addresses.select do |address|
        cities.as( Array ).includes? address.city.to_i
      end : Addresses
  end
end

module TestSchema
  extend GraphQL::Schema
  query SpecialQuery
end
