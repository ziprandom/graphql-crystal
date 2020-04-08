require "../../../src/graphql-crystal/types/object_type"

module Dummy
  class Cheese
    include GraphQL::ObjectType
    getter :source

    def initialize(
      @id : Int32, @flavour : String,
      @origin : String, @fat_content : Float64, @source : String | Int32
    ); end
  end

  CHEESES = {
    1 => Cheese.new(1, "Brie", "France", 0.19, 1),
    2 => Cheese.new(2, "Gouda", "Netherlands", 0.3, 1),
    3 => Cheese.new(3, "Manchego", "Spain", 0.065, "SHEEP"),
  }

  class Milk
    include GraphQL::ObjectType
    getter :source

    def initialize(
      @id : Int32, @fat_content : Float64,
      @origin : String, @source : Int32, @flavours : Array(String)
    ); end
  end

  MILKS = {
    1 => Milk.new(1, 0.04, "Antiquity", 1, ["Natural", "Chocolate", "Strawberry"]),
  }

  module DAIRY
    include GraphQL::ObjectType
    extend self

    ID     = 1
    CHEESE = CHEESES[1]
    MILKS  = [MILKS[1]]
  end

  module COW
    extend GraphQL::ObjectType
    ID                  = 1
    NAME                = "Billy"
    LAST_PRODUCED_DAIRY = MILKS[1]
  end

  module MAYBENULL
    extend GraphQL::ObjectType
    CHEESE = nil
  end
end
