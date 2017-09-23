require "spec"
require "../src/graphql-crystal"

#
# Given this simple domain model of users and posts
#
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

#
# We can instantiate a GraphQL Schema Validator/Executor
# by parsing from a graphql schema definition
#

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

#
# Then we create the backing types by including the
# GraphQL::ObjectType and defining the fields

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

#
# A Struct to hold input parameters
#
struct PostInput < GraphQL::Schema::InputType
  JSON.mapping(
    author: String,
    title: String,
    body: String
  )
end
schema.add_input_type("PostInput", PostInput)

#
# Then we define the top level queries
# extending self to make the module
# act as a singleton model
module QueryType
  include GraphQL::ObjectType
  extend self

  field :users do
    USERS
  end

  field :user do |args|
    USERS.find( &.name.==(args["name"].as(String)) ) || raise "no user by that name"
  end

  field :posts do
    POSTS
  end
end

module MutationType
  include GraphQL::ObjectType
  extend self

  field :post do |args|
    input = args["post"].as(PostInput)

    author = USERS.find &.name.==(input.author) ||
           raise "author doesn't exist"

    POSTS << Post.new(input.title, input.body, author)
    POSTS.last
  end
end

#
# finally set the top level Object Types
# on the schema
schema.query_resolver = QueryType
schema.mutation_resolver = MutationType

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

  it "does introspection" do

    query_string = %{
      {
        __schema {
          types {
            name
          }
        }
      }
    }


    schema.execute(query_string)
      .should eq ({
                    "data" => {
                      "__schema" => {
                        "types" => [
                          {"name" => "String"},
                          {"name" => "Boolean"},
                          {"name" => "Int"},
                          {"name" => "Float"},
                          {"name" => "ID"},
                          {"name" => "QueryType"},
                          {"name" => "MutationType"},
                          {"name" => "PostInput"},
                          {"name" => "UserType"},
                          {"name" => "PostType"},
                          {"name" => "__Schema"},
                          {"name" => "__Type"},
                          {"name" => "__Field"},
                          {"name" => "__InputValue"},
                          {"name" => "__EnumValue"},
                          {"name" => "__Directive"},
                          {"name" => "__TypeKind"},
                          {"name" => "__DirectiveLocation"}
                        ]
                      }
                    }
                  }
                 )
  end
end
