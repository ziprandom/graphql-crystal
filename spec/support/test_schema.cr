# coding: utf-8
require "../src/graphql-crystal/schema"

Addresses = [
  {"Downing Street", 11, "London", 3231},
  {"Sunset Boulevard", 114, "Miami", 123439},
  {"Avenida Santa Fé", 3042, "CABA", 12398}
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
        @city : String, @postal_code : Int32)
  end
  field :street, StringType
  field :number, IntegerType
  field :city, StringType
  field :postal_code, IntegerType
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
  field :id, IDType
  field :name, StringType
  field :address, Address
  field :friends, ListType(User).new
  field :full_address, StringType do
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
  field :user, User, "A user in the system.", { id: IDType } do
    Users.find &.id.==( args["id"] )
  end
end

enum CityEnum
  London
  Miami
  CABA
  Istanbul
end

alias CityType = EnumType( CityEnum )

# just to make sure it keeps
# working with inheritance
class SpecialQuery < Query

  field :addresses, ListType( Address ).new, "an address in the system",
        { city: ListType( CityType ).new } do
    (cities = args["city"]?) ?
      Addresses.select do |address|
        cities.as( Array ).includes? address.city
      end : Addresses
  end
end

module TestSchema
  extend GraphQL::Schema
  query SpecialQuery

end
