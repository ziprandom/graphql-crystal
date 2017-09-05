# graphql-crystal [![Build Status](https://api.travis-ci.org/ziprandom/graphql-crystal.svg)](https://travis-ci.org/ziprandom/graphql-crystal)


A implementation of [GraphQL](http://graphql.org/learn/) for the crystal programming language inspired by [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) & [go-graphql](https://github.com/playlyfe/go-graphql).

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

In order to create a GraphQL Schema and execute queries and mutations against it three steps have to be performed:

1. define a GraphQL Schema in the [graphql schema definition language](http://graphql.org/learn/schema/)
2. reopen existing domain models to act as graphql object types by including the ```GraphQL::ObjectType``` and defining accessable fields.
3. define the resolve callbacks for the root queries and mutations.

### Example

All the following code can be found in [example/simple_blog_example.cr](example/simple_blog_example.cr).

We will assume a very simple domain model for a web application that gives us some users with different user roles, posts and comments:

```crystal
require "graphql-crystal"
require "secure_random"

enum UserRole
  Author
  Reader
  Admin
end

#
# Lets create a simple Blog Scenario where there exist Users, Posts and Comments
#
# First we define 4 classes to represent our Model: User, Content, Post < Content & Comment < Content
#

class User
  getter :id, :first_name, :last_name, :role
  def initialize(
    @id : String, @first_name : String,
    @last_name : String, @role : UserRole); end
end

abstract class Content
  # due to https://github.com/crystal-lang/crystal/issues/4580
  # we have to include the ObjectType module at the first definition of Content
  # in order for the field macro to work on child classes. Once this is fixed the
  # arbitrary classes can declared as GraphQL Object types easily via monkey Patching
  include GraphQL::ObjectType
  @id: String
  @body: String
  @author: User
  def initialize(@id, @body, @author); end
end

class Post < Content
  getter :id, :author, :title, :body
  def initialize(@id : String, @author : User,
    @title : String, @body : String); end
end

class Comment < Content
  getter :id, :author, :post, :body
  def initialize(@id : String, @author : User,
    @post : Post, @body : String); end
end

#
# and create some fixtures to work with
#
USERS = [
  {
   id: SecureRandom.uuid, first_name: "Bob",
   last_name: "Bobson", role: UserRole::Author
  },{
   id: SecureRandom.uuid, first_name: "Alice",
   last_name: "Alicen", role: UserRole::Admin
  },{
    id: SecureRandom.uuid, first_name: "Grace",
    last_name: "Graham", role: UserRole::Reader
  }
].map { |args| User.new **args }

POSTS = [
  {
    id: SecureRandom.uuid, author: USERS[0],
    title: "GraphQL for Dummies", body: "GraphQL is pretty simple."
  },{
    id: SecureRandom.uuid, author: USERS[0],
    title: "REST vs. GraphQL", body: "GraphQL has certain advantages over REST."
  },{
    id: SecureRandom.uuid, author: USERS[1], title: "The Crystal Programming Language ",
    body: "The nicest syntax on the planet now comes with typesafety, performance and parallelisation support(ójala!)"
  }
].map { |args| Post.new **args }

COMMENTS = [
  {
    id: SecureRandom.uuid, author: USERS[2],
    post: POSTS[1], body: "I like rest more!"
  },{
    id: SecureRandom.uuid, author: USERS[2],
    post: POSTS[1], body: "But think of all the possibilities with GraphQL!"
  },{
    id: SecureRandom.uuid, author: USERS[1],
    post: POSTS[2], body: "When will I finally have static compilation support?"
  }
].map { |args| Comment.new **args }
```

Based on this data we define a graphql schema using the schema definition language:

```crystal
graphql_schema_definition = <<-graphql_schema
  schema {
    query: QueryType,
    mutation: MutationType
  }

  type QueryType {
    # retrieve a user by id
    user(id: ID!): User
    # retrieve a post by id
    post(id: ID!): Post
    # get all posts
    posts: [Post!]
  }

  type MutationType {
    # create a new post
    post(payload: PostInput!): Post
    # create a new comment
    comment(payload: CommentInput!): Comment
  }

  # Input format for
  # new Posts
  input PostInput {
    # title for the new post
    title: String!
    # body for the new post
    body: String!
    # id of the posts author
    authorId: ID!
  }

  # Input format for
  # new Comments
  input CommentInput {
    # id of the post on
    # which is being commented
    postId: ID!
    # id of the comments author
    authorId: ID!
    # the comments text
    body: String!
  }

  # Possible roles
  # for users in the system
  enum UserRole {
    # A user with
    # readonly access to
    # the Content of the system
    Reader
    # A user with read
    # & write access
    Author
    # A administrator
    # of the system
    Admin
  }

  # Types identified by a
  # unique ID
  interface UniqueId {
    # the unique idenfifier
    # for this entity
    id: ID!
  }

  # A User
  type User implements UniqueId {
    # users first name
    firstName: String!
    # users last name
    lastName: String!
    # full name string for the user
    fullName: String!
    # users role
    role: UserRole!
    # posts published
    # by this user
    posts: [Post!]
    # total number of posts
    # published by this user
    postsCount: Int!
  }

  # Text content
  interface Content {
    # text body of this entity
    body: String!
    # author of this entity
    author: User!
  }

  # A post in the system
  type Post implements UniqueId, Content {
    # title of this post
    title: String!
  }

  # A comment on a post
  type Comment implements UniqueId, Content {
    # post on which this
    # comment was made
    post: Post!
  }
graphql_schema
```

and instantiate a ```GraphQL::Schema``` with it using the ```.from_schema``` class method:

```crystal
schema = GraphQL::Schema.from_schema(graphql_schema_definition)
```

next we reopen our domain model classes and enhance them to act as GraphQL Objects:

```crystal
abstract class Content
  # this doesn't work here atm. due to
  # https://github.com/crystal-lang/crystal/issues/4580
  # so we had to include the module at the first
  # declaration of the Content class above
  # include GraphQL::ObjectType
  field :id
  field :body
  field :author
end

# you see it works nicely with inheritance
class Post
  field :title
end

class Comment
  field :post
end

#
# Here we make use of custom callbacks
# to convert snake_case to camelCase
# and add virtual accessors
#
class User
  include GraphQL::ObjectType
  field :firstName { first_name }
  field :lastName { last_name }
  field :fullName { "#{@first_name} #{@last_name}" }
  field :posts { POSTS.select &.author.==(self)}
  field :postsCount { POSTS.select( &.author.==(self) ).size }
  field :role
end
```

in the last step we define the entrypoints of the schema by providing the logic for the RootQuery and RootMutation Fields:

```crystal
schema.resolve do

  query "posts" { POSTS }

  query "user" do |args|
    USERS.find( &.id.==(args["id"]) )
  end

  query "post" do |args|
    POSTS.find( &.id.==(args["id"]) )
  end

  mutation "post" do |args|
    payload = args["payload"].as(Hash)

    author = USERS.find( &.id.==(payload["authorId"]) )
    raise "authorId doesn't exist!" unless author

    post = Post.new(
      id: SecureRandom.uuid, author: author,
      title: payload["title"].as(String), body: payload["body"].as(String)
    )

    POSTS << post
    post
  end

  mutation "comment" do |args|
    payload = args["payload"].as(Hash)

    author = USERS.find( &.id.==(payload["authorId"]) )
    raise "authorId doesn't exist!" unless author

    post = POSTS.find( &.id.==(payload["postId"]) )
    raise "postId doesn't exist!" unless post

    comment = Comment.new(
      id: SecureRandom.uuid, author: author,
      post: post, body: payload["body"].as(String)
    )
    COMMENTS << comment
    comment
  end

end
```

This is all we need to define a GraphQL Schema and serve our Application Data.

Lets run an simple introspection query:

```crystal
puts schema.execute("{ __type(name: \"Post\") { fields { name description type { kind } } } }").to_pretty_json
```

```json
{
  "data": {
    "__type": {
      "fields": [
        {
          "name": "author",
          "description": "author of this entity",
          "type": {
            "kind": "NON_NULL"
          }
        },
        {
          "name": "body",
          "description": "text body of this entity",
          "type": {
            "kind": "NON_NULL"
          }
        },
        {
          "name": "id",
          "description": "the unique idenfifier for this entity",
          "type": {
            "kind": "NON_NULL"
          }
        },
        {
          "name": "title",
          "description": "title of this post",
          "type": {
            "kind": "NON_NULL"
          }
        }
      ]
    }
  }
}
```

And request all the posts:

```crystal
puts schema.execute(" { posts { id title body author { fullName } } } ").to_pretty_json
```

```json
{
  "data": {
    "posts": [
      {
        "id": "a9b55bc6-5bcc-4828-8527-542015af830e",
        "title": "GraphQL for Dummies",
        "body": "GraphQL is pretty simple.",
        "author": {
          "fullName": "Bob Bobson"
        }
      },
      {
        "id": "3f8d01af-41ff-417d-998b-f832ac5d31ee",
        "title": "REST vs. GraphQL",
        "body": "GraphQL has certain advantages over REST.",
        "author": {
          "fullName": "Bob Bobson"
        }
      },
      {
        "id": "b13cdefd-859a-4b13-ae34-cf7b3c60205e",
        "title": "The Crystal Programming Language ",
        "body": "The nicest syntax on the planet now comes with typesafety, performance and parallelisation support(ójala!)",
        "author": {
          "fullName": "Alice Alicen"
        }
      }
    ]
  }
}
```

Next let's create a mutation to push a Post:

```crystal
mutation_string = %{
  mutation CreatePost($payload: PostInput) {
    post(payload: $payload) {
      id
      title
      body
      author {
        postsCount
      }
    }
  }
}

mutation_args = {
  "payload" => {
    "title" => "Using Crystal 1.0 in Production",
    "body" => "would be the most wonderful thing",
    "authorId" => USERS.first.id
  }
}
puts schema.execute(mutation_string, mutation_args).to_pretty_json
```

```json
{
  "data": {
    "post": {
      "id": "a8ad1fea-2a07-4aef-a6f3-a9051cce15e8",
      "title": "Using Crystal 1.0 in Production",
      "body": "would be the most wonderful thing",
      "author": {
        "postsCount": 3
      }
    }
  }
}
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
