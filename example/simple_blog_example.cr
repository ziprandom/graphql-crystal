# coding: utf-8
require "../src/graphql-crystal"
require "secure_random"
require "benchmark"

module BlogExample
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
    def initialize(@id : String, @first_name : String, @last_name : String, @role : UserRole); end
  end

  abstract class Content
    #
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
    def initialize(@id : String, @author : User, @title : String, @body : String); end
  end

  class Comment < Content
    getter :id, :author, :post, :body
    def initialize(@id : String, @author : User, @post : Post, @body : String); end
  end

  #
  # and create some fixtures to work with
  #
  #
  # and create some fixtures to work with
  #
  USERS = [
    {id: SecureRandom.uuid, first_name: "Bob", last_name: "Bobson", role: UserRole::Author},
    {id: SecureRandom.uuid, first_name: "Alice", last_name: "Alicen", role: UserRole::Admin},
    {id: SecureRandom.uuid, first_name: "Grace", last_name: "Graham", role: UserRole::Reader}
  ].map { |args| User.new **args }

  POSTS = [
    {id: SecureRandom.uuid, author: USERS[0], title: "GraphQL for Dummies", body: "GraphQL is pretty simple."},
    {id: SecureRandom.uuid, author: USERS[0], title: "REST vs. GraphQL", body: "GraphQL has certain advantages over REST."},
    {id: SecureRandom.uuid, author: USERS[1], title: "The Crystal Programming Language ", body: "The nicest syntax on the planet now comes with typesafety, performance and parallelisation support(ójala!)"}
  ].map { |args| Post.new **args }

  COMMENTS = [
    {id: SecureRandom.uuid, author: USERS[2], post: POSTS[1], body: "I like rest more!"},
    {id: SecureRandom.uuid, author: USERS[2], post: POSTS[1], body: "But think of all the possibilities with GraphQL!"},
    {id: SecureRandom.uuid, author: USERS[1], post: POSTS[2], body: "When will I finally have static compilation support?"}
  ].map { |args| Comment.new **args }


  #
  # Now we define our Schema
  #

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

  # load it
  schema = GraphQL::Schema.from_schema(graphql_schema_definition)

  module UniqueId
    macro included
      field :id
    end
  end

  # Here we reopen the classes
  # of our application model and
  # enhance them to act as GraphQL Object Types via the GraphQL::ObjectType
  # and define the available fields via the field macro. fields resolve to an
  # instanc emethod of the same name unless stated otherwise
  abstract class Content
    # this doesn't work here due to https://github.com/crystal-lang/crystal/issues/4580
    # so we included the module at the first declaration of the Content class above
    # include GraphQL::ObjectType
    include UniqueId
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
    include UniqueId
    field :firstName { first_name }
    field :lastName { last_name }
    field :fullName { "#{@first_name} #{@last_name}" }
    field :posts { POSTS.select &.author.==(self)}
    field :postsCount { POSTS.select( &.author.==(self) ).size }
    field :role
  end

  module QueryType
    include GraphQL::ObjectType
    extend self

    field "posts" { POSTS }

    field "user" do |args|
      USERS.find( &.id.==(args["id"]) )
    end

    field "post" do |args|
      POSTS.find( &.id.==(args["id"]) )
    end

  end

  module MutationType
    include GraphQL::ObjectType
    extend self

    field "post" do |args|
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

    field "comment" do |args|
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

  #
  # finally we assign the top level query & mutation types
  #
  schema.query_resolver = QueryType
  schema.mutation_resolver = MutationType
end

#
# execute a simple query
#
puts schema.execute("{ posts {id title body author {fullName}} }").to_pretty_json


#
# a simple introspection query:
#
puts schema.execute("{ __type(name: \"Post\") { fields { name description type { kind } } } }").to_pretty_json


#
# create a Post via a mutation
#
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
    "authorId" => BlogExample::USERS.first.id
  }
}

puts schema.execute(mutation_string, mutation_args).to_pretty_json


#
# comment on the post we just created
#
mutation_string = %{
  mutation CreateComment($payload: CommentInput) {
    comment(payload: $payload) {
      id
      body
    }
  }
}

mutation_args = {
  "payload" => {
    "postId" => BlogExample::POSTS.last.id,
    "body" => "would be the most wonderful thing",
    "authorId" => BlogExample::USERS[1].id
  }
}

puts schema.execute(mutation_string, mutation_args).to_pretty_json


# lets create lots of Comments

Benchmark.ips do |x|
  x.report("commenting on that post") do
    schema.execute(mutation_string, mutation_args).to_json
  end
end
