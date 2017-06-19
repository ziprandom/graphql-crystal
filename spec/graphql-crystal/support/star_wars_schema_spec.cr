require "../../spec_helper"

describe StarWarsSchema do
  describe "Basic Queries" do
    it "Correctly identifies R2-D2 as the hero of the Star Wars Saga" do
      query_string = %{
        query HeroNameQuery {
          hero {
            name
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "hero" => {
                              "name" => "R2-D2"
                            }
                          }
                        })
    end
    it "Allows us to query for the ID and friends of R2-D2" do
      query_string = %{
        query HeroNameAndFriendsQuery {
          hero {
            id
            name
            friends {
              name
            }
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "hero" =>  {
                              "id" => "2001",
                              "name" => "R2-D2",
                              "friends" =>  [
                                {
                                  "name" => "Luke Skywalker",
                                },
                                {
                                  "name" => "Han Solo",
                                },
                                {
                                  "name" => "Leia Organa",
                                },
                              ]
                            }
                          }
                        })
    end
  end
  describe "Nested Queries" do
    it "Allows us to query for the ID and friends of R2-D2" do
      query_string = %{
        query NestedQuery {
          hero {
            name
            friends {
              name
              appearsIn
              friends {
                name
              }
            }
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "hero" => {
                              "name" => "R2-D2",
                              "friends" => [
                                {
                                  "name" => "Luke Skywalker",
                                  "appearsIn" => [ "NEWHOPE", "EMPIRE", "JEDI" ],
                                  "friends" => [
                                    {
                                      "name" => "Han Solo",
                                    },
                                    {
                                      "name" => "Leia Organa",
                                    },
                                    {
                                      "name" => "C-3PO",
                                    },
                                    {
                                      "name" => "R2-D2",
                                    },
                                  ]
                                },
                                {
                                  "name" => "Han Solo",
                                  "appearsIn" => [ "NEWHOPE", "EMPIRE", "JEDI" ],
                                  "friends" => [
                                    {
                                      "name" => "Luke Skywalker",
                                    },
                                    {
                                      "name" => "Leia Organa",
                                    },
                                    {
                                      "name" => "R2-D2",
                                    },
                                  ]
                                },
                                {
                                  "name" => "Leia Organa",
                                  "appearsIn" => [ "NEWHOPE", "EMPIRE", "JEDI" ],
                                  "friends" => [
                                    {
                                      "name" => "Luke Skywalker",
                                    },
                                    {
                                      "name" => "Han Solo",
                                    },
                                    {
                                      "name" => "C-3PO",
                                    },
                                    {
                                      "name" => "R2-D2",
                                    },
                                  ]
                                },
                              ]
                            }
                          }
                        })
    end
  end

  describe "Using IDs and query parameters to refetch objects" do
    it "Allows us to query for Luke Skywalker directly, using his ID" do
      query_string = %{
        query FetchLukeQuery {
          human(id: "1000") {
            name
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "human" => {
                              "name" => "Luke Skywalker"
                            }
                          }
                        })
    end

    it "Allows us to create a generic query, then use it to fetch Luke Skywalker using his ID" do
      query_string = %{
        query FetchSomeIDQuery($someId: String!) {
          human(id: $someId) {
            name
          }
        }
      }
      params = { "someId" => "1000" }
      result = StarWarsSchema.execute(query_string, params)
      result.should eq ({
                          "data" => {
                            "human" => {
                              "name" => "Luke Skywalker"
                            }
                          }
                        })
    end

    it "Allows us to create a generic query, then use it to fetch Luke Skywalker using his ID" do
      query_string = %{
        query FetchSomeIDQuery($someId: String!) {
          human(id: $someId) {
            name
          }
        }
      }
      params = { "someId" => "1002" }
      result = StarWarsSchema.execute(query_string, params)
      result.should eq ({
                          "data" => {
                            "human" => {
                              "name" => "Han Solo"
                            }
                          }
                        })
    end

    it "Allows us to create a generic query, then pass an invalid ID to get null back" do
      query_string = %{
        query humanQuery($id: String!) {
          human(id: $id) {
            name
          }
        }
      }
      params = { "id" => "not a valid id" }
      result = StarWarsSchema.execute(query_string, params)
      result.should eq ({
                          "data" => {
                            "human" => nil
                          }
                        })
    end
  end

  it "Using aliases to change the key in the response" do
    it "Allows us to query for Luke, changing his key with an alias" do
      query_string = %{
        query FetchLukeAliased {
          luke: human(id: "1000") {
            name
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "luke" => {
                              "name" => "Luke Skywalker"
                            }
                          }
                        })
    end

    it "Allows us to query for both Luke and Leia, using two root fields and an alias" do
      query_string = %{
        query FetchLukeAndLeiaAliased {
          luke: human(id: "1000") {
            name
          }
          leia: human(id: "1003") {
            name
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "luke" => {
                              "name" => "Luke Skywalker"
                            },
                            "leia" => {
                              "name" => "Leia Organa"
                            }
                          }
                        })
    end
  end

  describe "Uses fragments to express more complex queries" do
    it "Allows us to query using duplicated content" do
      query_string = %{
        query DuplicateFields {
          luke: human(id: "1000") {
            name
            homePlanet
          }
          leia: human(id: "1003") {
            name
            homePlanet
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "luke" => {
                              "name" => "Luke Skywalker",
                              "homePlanet" => "Tatooine"
                            },
                            "leia" => {
                              "name" => "Leia Organa",
                              "homePlanet" => "Alderaan"
                            }
                          }
                        })
    end

    it "Allows us to use a fragment to avoid duplicating content" do
      query_string = %{
        query UseFragment {
          luke: human(id: "1000") {
            ...HumanFragment
          }
          leia: human(id: "1003") {
            ...HumanFragment
          }
        }
        fragment HumanFragment on Human {
          name
          homePlanet
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "luke" => {
                              "name" => "Luke Skywalker",
                              "homePlanet" => "Tatooine"
                            },
                            "leia" => {
                              "name" => "Leia Organa",
                              "homePlanet" => "Alderaan"
                            }
                          }
                        })
    end
  end
  describe "Using __typename to find the type of an object" do
    it "Allows us to verify that R2-D2 is a droid" do
      query_string = %{
        query CheckTypeOfR2 {
          hero {
            __typename
            name
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
                          "data" => {
                            "hero" => {
                              "__typename" => "Droid",
                              "name" => "R2-D2"
                            }
                          }
                        })
    end

    it "Allows us to verify that Luke is a human" do
      query_string = %{
        query CheckTypeOfLuke {
          hero(episode: EMPIRE) {
            __typename
            name
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
        "data" => {
          "hero" => {
            "__typename" => "Human",
            "name" => "Luke Skywalker"
          }
        }
      })
    end
  end

  describe "Reporting errors raised in resolvers" do
    it "Correctly reports error on accessing secretBackstory" do
      query_string = %{
        query HeroNameQuery {
          hero {
            name
            secretBackstory
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
        "data" => {
          "hero" => {
            "name" => "R2-D2",
            "secretBackstory": nil
          }
        },
        "errors" => [
          {
            "message" => "secretBackstory is secret.",
            # no location data available atm :(
            # "locations" => [ { "line" => 5, "column" => 13 } ],
            "path" => [ "hero", "secretBackstory" ]
          }
        ]
      })
    end

    it "Correctly reports error on accessing secretBackstory in a list" do
      query_string = %{
        query HeroNameQuery {
          hero {
            name
            friends {
              name
              secretBackstory
            }
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
        "data" => {
          "hero" => {
            "name" => "R2-D2",
            "friends": [
              {
                "name" => "Luke Skywalker",
                "secretBackstory": nil
              },
              {
                "name" => "Han Solo",
                "secretBackstory": nil
              },
              {
                "name" => "Leia Organa",
                "secretBackstory": nil,
              },
            ]
          }
        },
        "errors" => [
          {
            "message" => "secretBackstory is secret.",
#            "locations" => [ { "line" => 7, "column" => 15 } ],
            "path" => [ "hero", "friends", 0, "secretBackstory" ]
          },
          {
            "message" => "secretBackstory is secret.",
#            "locations" => [ { "line" => 7, "column" => 15 } ],
            "path" => [ "hero", "friends", 1, "secretBackstory" ]
          },
          {
            "message" => "secretBackstory is secret.",
#            "locations" => [ { "line" => 7, "column" => 15 } ],
            "path" => [ "hero", "friends", 2, "secretBackstory" ]
          }
        ]
      })
    end

    it "Correctly reports error on accessing through an alias" do
      query_string = %{
        query HeroNameQuery {
          mainHero: hero {
            name
            story: secretBackstory
          }
        }
      }
      result = StarWarsSchema.execute(query_string)
      result.should eq ({
        "data" => {
          "mainHero" => {
            "name" => "R2-D2",
            "story" => nil
          }
        },
        "errors" => [
          {
            "message" => "secretBackstory is secret.",
#            "locations" => [ { "line" => 5, "column" => 13 } ],
            "path" => [ "mainHero", "story" ]
          }
        ]
      })
    end
  end
end
