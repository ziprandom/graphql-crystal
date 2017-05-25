require "../../src/graphql-crystal/schema";

schema_string = <<-schema
  schema {
    query: QueryType,
    mutation: MutationType
  }

  input MessageInput {
    content: String
    author: String
  }

  type Message {
    id: ID!
    content: String
    author: String
    previous: [Message]
  }

  type QueryType {
    getMessage(id: ID!): Message
  }

  type MutationType {
    createMessage(input: MessageInput): Message
    updateMessage(id: ID!, input: MessageInput): Message
  }
schema

class Message
  include GraphQL::ObjectType

  field :id, GraphQL::IDType
  field :author, GraphQL::StringType
  field :content, GraphQL::StringType
  field :previous, Message do
    @@messages.select &.id.<(id)
  end

  property id : Int32, :content, :author
  @@last_id = 0;
  @@messages = [] of Message
  def initialize(@content : String = "", @author : String = "")
    @@last_id += 1
    @id = @@last_id
    @@messages << self
  end
end


messages = [Message.new("hello world", "juan"), Message.new("hello juan", "celia")]
pp messages.first.responds_to? :resolve
schema = GraphQL::Schema.from_schema(schema_string).resolve do

  query :getMessage do |args|
    messages.find &.id.==(args["id"])
  end

  mutation :createMessage do |args|
    messages << Message.new(content: args["input"].as(Hash)["content"].as(String), author: args["input"].as(Hash)["author"].as(String))
    messages.last
  end

  mutation :updateMessage do |args|
    message = messages.find &.id.==(args["id"])
    if message
      message.author = args["input"].as(Hash)["author"].as(String)
      message.content = args["input"].as(Hash)["content"].as(String)
    end
    message
  end

end

res = schema.execute("{ getMessage(id: 1) { author content previous { author } } }")
puts res.to_pretty_json
mutation = <<-mut
mutation  {
  createMessage(input: { content: "a message", author: "me" }) { id author content }
}
mut
3.times { res = schema.execute(mutation) }

puts res.to_pretty_json
res = schema.execute("{ getMessage(id: 3) { id author content } }")
puts res.to_pretty_json


mutation = <<-mut
mutation  {
  updateMessage(id: 4, input: { content: "a message", author: "jean paul sartre"} ) { ... messageFragment }
}
fragment messageFragment on Message {
  id author content somth: previous { id author }
}
mut
res = schema.execute(mutation)
puts res.to_pretty_json
