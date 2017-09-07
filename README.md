# graphql-crystal [![Build Status](https://api.travis-ci.org/ziprandom/graphql-crystal.svg)](https://travis-ci.org/ziprandom/graphql-crystal)


An implementation of [GraphQL](http://graphql.org/learn/) for the crystal programming language inspired by [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) & [go-graphql](https://github.com/playlyfe/go-graphql).

The library is in beta state atm. Should already be usable but expect to find bugs (and open issues about them). pull-requests, suggestions & criticism are very welcome!

Find the api docs [here](https://ziprandom.github.io/graphql-crystal/).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  graphql-crystal:
    github: ziprandom/graphql-crystal
```

## Usage

Complete source [here](example/simple_example.cr).

Given this simple domain model of users and posts

```cr
class User
  property name
  def initialize(@name : String); end
end

class Post
  property :title, :body, :author
  def initialize(@title : String, @body : String, @author : User); end
end

POSTS = [] of Post
USERS = [User.new("Alice"), User.new("Bob")]
```

We can instantiate a GraphQL schema directly from a graphql schema definition string

```cr
schema = GraphQL::Schema.from_schema(
  %{
    schema {
      query: QueryType,
      mutation: MutationType
    }

    type QueryType {
      posts: [PostType]
      users: [UserType]
      user(name: String!): User
    }

    type MutationType {
      post(post: PostInput) : PostType
    }

    input PostInput {
      author: String!
      title: String!
      body: String!
    }

    type UserType {
      name: String
      posts: [PostType]
    }

    type PostType {
      author: UserType
      title: String
      body: String
    }
  }
)
```

Then we create the backing types by including the ```GraphQL::ObjectType``` and defining the fields using the ```field``` macro

```cr
# reopening User and Post class
class User
  include GraphQL::ObjectType

  # defaults to the method of
  # the same name without block
  field :name

  field :posts do
    POSTS.select &.author.==(self)
  end
end

class Post
  include GraphQL::ObjectType
  field :title
  field :body
  field :author
end
```

Now we define the top level queries

```cr
# extend self when using a module or a class (not an instance)
# as the actual Object

module QueryType
  include GraphQL::ObjectType
  extend self

  field :users do
    USERS
  end

  field :user do |args|
    begin
      USERS.find &.name.==( args["name"].as(String) )
    rescue
      raise "no user by that name"
    end
  end

  field :posts do
    POSTS
  end
end

module MutationType
  include GraphQL::ObjectType
  extend self

  field :post do |args|

    user = USERS.find &.name.==(
      args["post"].as(Hash)["author"].as(String)
    )
    raise "author doesn't exist" unless user

    (
      POSTS << Post.new(
        args["post"].as(Hash)["title"].as(String),
        args["post"].as(Hash)["body"].as(String),
        user
      )
    ).last
  end
end
```

Finally set the top level Object Types on the schema

```cr
schema.query_resolver = QueryType
schema.mutation_resolver = MutationType
```

And we are ready to run some tests

```cr
describe "my graphql schema" do
  it "does queries" do
    schema.execute("{ users { name posts } }")
      .should eq ({
                    "data" => {
                      "users" => [
                        {
                          "name" => "Alice",
                          "posts" => [] of String
                        },
                        {
                          "name" => "Bob",
                          "posts" => [] of String
                        }
                      ]
                    }
                  })
  end

  it "does mutations" do

    mutation_string = %{
      mutation post($post: PostInput) {
        post(post: $post) {
          author {
            name
            posts { title }
          }
          title
          body
        }
      }
    }

    payload = {
      "post" => {
        "author" =>  "Alice",
        "title" => "the long and windy road",
        "body" => "that leads to your door"
      }
    }

    schema.execute(mutation_string, payload)
      .should eq ({
                    "data" => {
                      "post" => {
                        "title" => "the long and windy road",
                        "body" => "that leads to your door",
                        "author" => {
                          "name" => "Alice",
                          "posts" => [
                            {
                              "title" => "the long and windy road"
                            }
                          ]
                        }
                      }
                    }
                  })
  end
end
```

### Custom Context Types

Custom context types can be used to pass additional information to the object type's field resolves. An example can be found [here](spec/support/custom_context_schema.cr).

A Custom context type should inherit from `GraphQL::Schema::Context` and therefore be initialized with the served schema and a max_depth.

```cr
GraphQL::Schema::Schema#execute(query_string, query_arguments = nil, context = GraphQL::Schema::Context.new(self, max_depth))
```
accepts a context type as its third argument.

Field Resolver Callbacks on Object Types (including top level Query & Mutation Type) get called with the context as their third argument:
```cr
field :users do |args, context|
  # casting to your custom type
  # is necessary here
  context = context.as(CustomContext)
  unless context.authenticated
    raise "Authentication Error"
  end
  ...
end
```

## Parser Performance

The parser has been implemented using my [crystal language toolkit](https://github.com/ziprandom/cltk) and does not have optimal performance atm.

To compare the performance of the Parser with [facebooks GraphQL parser](https://github.com/graphql/libgraphqlparser) you need to have the library installed on your machine. Then run

```sh
crystal build --release benchmark/compare_benchmarks.cr
```

### Recent Results:

```sh
c implementation from facebook:   47.29k ( 21.15µs) (± 0.70%)       fastest
     cltk based implementation:  904.46  (  1.11ms) (± 0.96%) 52.28× slower
```

## Development

run tests with

```
crystal spec
```

## Contributing

1. Fork it ( https://github.com/ziprandom/graphql-crystal/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [ziprandom](https://github.com/ziprandom)  - creator, maintainer
