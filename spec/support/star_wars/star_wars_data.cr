module StarWars
  enum EpisodeEnum
    NEWHOPE = 4
    EMPIRE  = 5
    JEDI    = 6
  end

  class Character
    include GraphQL::ObjectType
    getter :id, :name, :friends, :appears_in

    def initialize(@id : String, @name : String, @friends : Array(String),
                   @appears_in : Array(EpisodeEnum)); end
  end

  class Human < Character
    getter :home_planet

    def initialize(@id : String, @name : String, @friends : Array(String),
                   @appears_in : Array(EpisodeEnum), @home_planet : String?); end
  end

  class Droid < Character
    getter :primary_function

    def initialize(@id : String, @name : String, @friends : Array(String),
                   @appears_in : Array(EpisodeEnum), @primary_function : String?); end
  end

  CHARACTERS = begin
    luke = {
      type:        "Human",
      id:          "1000",
      name:        "Luke Skywalker",
      friends:     ["1002", "1003", "2000", "2001"],
      appears_in:  [4, 5, 6],
      home_planet: "Tatooine",
    }

    vader = {
      type:        "Human",
      id:          "1001",
      name:        "Darth Vader",
      friends:     ["1004"],
      appears_in:  [4, 5, 6],
      home_planet: "Tatooine",
    }

    han = {
      type:       "Human",
      id:         "1002",
      name:       "Han Solo",
      friends:    ["1000", "1003", "2001"],
      appears_in: [4, 5, 6],
    }

    leia = {
      type:        "Human",
      id:          "1003",
      name:        "Leia Organa",
      friends:     ["1000", "1002", "2000", "2001"],
      appears_in:  [4, 5, 6],
      home_planet: "Alderaan",
    }

    tarkin = {
      type:       "Human",
      id:         "1004",
      name:       "Wilhuff Tarkin",
      friends:    ["1001"],
      appears_in: [4],
    }

    threepio = {
      type:             "Droid",
      id:               "2000",
      name:             "C-3PO",
      friends:          ["1000", "1002", "1003", "2001"],
      appears_in:       [4, 5, 6],
      primary_function: "Protocol",
    }

    artoo = {
      type:             "Droid",
      id:               "2001",
      name:             "R2-D2",
      friends:          ["1000", "1002", "1003"],
      appears_in:       [4, 5, 6],
      primary_function: "Astromech",
    }

    [luke, vader, han, leia, tarkin, threepio, artoo].map do |data|
      init_data = {
        data.values[1],
        data.values[2],
        data.values[3],
        data.values[4].map { |e| EpisodeEnum.from_value(e) },
        data.values[5]?,
      }
      if data[:type] == "Human"
        Human.new(*init_data)
      else
        Droid.new(*init_data)
      end
    end
  end
end
