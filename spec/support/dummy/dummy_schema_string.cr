module Dummy
  SCHEMA_STRING = <<-schema_string
    # something that comes from
    # somewhere
    interface LocalProduct {
      # Place the thing
      # comes from
      origin: String!
    }

    # something you can eat, yum
    interface Edible {
      # Percentage which is fat
      fatContent: Float!
      # Place the edible comes from
      origin: String!
      selfAsEdible: Edible
    }

    # comes from an animal,
    # no joke
    interface AnimalProduct {
      # Animal which produced
      # this product
      source: DairyAnimalEnum!
    }

    # Something you can drink
    union Beverage = Milk

    # An animal which can yield milk
    enum DairyAnimal {
      # Animal with black and white spots
      COW
      # Animal with fur
      DONKEY
      # Animal with horns
      GOAT
      # Animal with horns
      REINDEER
      # Animal with wool
      SHEEP
      # Animal with long hair
      YAK
    }

    # Cultured dairy product
    type Cheese implements Edible, AnimalProduct, LocalProduct {
      # Unique identifier
      id: Int!
      # Kind of Cheese
      flavor: String!
      # Place the cheese comes from
      origin: String!
      # Animal which produced the milk for this cheese
      source: DairyAnimal!
      # Cheeses like this one
      similarCheese: Cheese
      # Cheeses like this one
      nullableCheese: Cheese
      # Cheeses like this one"
      deeplyNullableCheese: Cheese @deprecated(reason: "no longer supported")
      # Percentage which is milkfat
      fatContent: Float!
    }

    # Dairy beverage
    type Milk implements Edible, AnimalProduct, LocalProduct {
      id: ID!
      # Animal which produced this milk
      source: DairyAnimal!
      # Place the milk comes from
      origin: String!
      # Chocolate, Strawberry, etc
      flavors(limit: Int): [String]
      executionError: String
      allDiary: [DairyProduct]
    }

    interface Sweetener {
      sweetness: Int
    }

    # Sweet, dehydrated bee barf
    type Honey implements Edible, AnimalProduct, Sweetener{
      # What flower this honey came from"
      flowerType: String
    }
    # A farm where milk is harvested and cheese is produced
    type Diary {
      id: ID!
      cheese: Cheese
      milks: [Milk]
    }

    # An object whose fields return nil
    type MaybeNull {
      cheese: Cheese
    }

    # Kinds of food made from milk
    # union DairyProduct {
    # }

    # A farm where milk is harvested
    # and cheese is produced
    type Cow {
      id: ID!
      name: String
      last_produced_dairy: DairyProduct
      cantBeNullButIs: String!
      cantBeNullButRaisesExecutionError: String!
    }

    # Properties used to determine ordering
    input ResourceOrderType {
      # ASC or DESC
      direction: String!
    }

    # Properties for finding a dairy product
    input DairyProductInput {
      # Where it came from
      source: DairyAnimal!
      # Dairy which produced it
      originDairy: String = "Sugar Hollow Dairy"
      # How much fat it has
      fatContent: Float = 0.3
      organic: Boolean = false
      order_by: ResourceOrderType = { direction: "ASC" }
    }

    type DeepNonNull {
      nonNullInt(returning: Int): Int!
      deepNonNull: DeepNonNull!
    }

    type ReplaceValuesInput {
      values: [Int!]!
    }

    # Query root of the system
    type DairyAppQuery {
        allDairy(executionErrorAtIndex: Int): [DairyProductUnion]
        allEdible: [EdibleInterface]!
        cheese: Cheese
        cow: Cow
        dairy: Dairy
        # To test possibly-null fields
        deepNonNull: DeepNonNull!
        # Raise an error
        error: String
        executionError: String
        # my favourite food
        favoriteEdible: Edible
        # Cheese from Source
        fromSource(source: dairyAnimal = COW): [Cheese]
        maybeNull:, MaybeNull
        milk: Milk
        root: String
        # Find dairy products matching a description
        searchDairy(product: [DairyProductInput] = [{source: "SHEEP" }]): DairyProductUnion!
        valueWithExecutionError: Int!
    }

    # The root for mutations in this schema
    type DairyAppMutation {
      # Push a value onto a
      # global array :D
      pushValue(value: Int): [Int!]!
      # Replace the global
      # array with new values
      replaceValues(input: ReplaceValuesInput!): [Int!]!
    }

    subscription Subscription {
      test: String
    }

    schema {
      query: DairyAppQuery
      mutation: DairyAppMutation
      subscription: Subscription
    }
  schema_string
end
