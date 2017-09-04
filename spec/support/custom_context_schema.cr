require "json"

class CustomContext < GraphQL::Schema::Context

  def initialize(@user : {authenticated: Bool, name: String}, @schema, @max_depth); end

  def authenticated
    @user[:authenticated]
  end

  def username
    @user[:name]
  end

end

class ProcessType
  include GraphQL::ObjectType
  JSON.mapping(
    name: String,
    pid: Int32
  )
  field name
  field pid
end

class LogType
  include GraphQL::ObjectType
  JSON.mapping(
    time: String,
    hostName: String,
    userName: String,
    process: ProcessType,
    message: String
  )
  field time
  field userName
  field hostName
  field process
  field message
end

module LogStore
  extend self
  TEMPFILENAME = "./__logs.log"

  `touch #{TEMPFILENAME}`;

  def read_logs
    raw_content = File.read(TEMPFILENAME)
    Array(LogType).from_json raw_content
  rescue
      [] of LogType
  end

  def write_logs(logs)
    File.write(TEMPFILENAME, logs.to_json);
  end
end

module QueryType
  include ::GraphQL::ObjectType
  extend self

  field :logs do |args, context|
    context = context.as(CustomContext)
    unless context.authenticated
      raise "you are not allowed to read the logs #{context.username}!"
    end
    LogStore.read_logs
  end
end

module MutationType
  include ::GraphQL::ObjectType
  extend self

  field :log do |args, context|
    context = context.as(CustomContext)

    unless context.authenticated
      raise "you are not allowed to read the logs #{context.username}!"
    end

    new_log = LogType.from_json(
      args["log"].as(Hash).merge({"userName"=> context.username}).to_json
    )

    LogStore.write_logs LogStore.read_logs << new_log
    new_log
  end
end

CUSTOM_CONTEXT_SCHEMA = ::GraphQL::Schema.from_schema(
  %{
    schema {
      query: QueryType,
      mutation: MutationType
    }

    type QueryType {
      logs: [LogType]
    }

    type MutationType {
      log(log: LogInput) : LogType
    }

    input LogInput {
      time: String!
      hostName: String!
      process: ProcessInput!
      message: String!
    }

    input ProcessInput {
      name: String!
      pid: ID
    }

    type LogType {
      time: String!
      userName: String!
      hostName: String!,
      process: ProcessType!
      message: String
    }

    type ProcessType {
      name: String!,
      pid: ID!
    }
  }
)

CUSTOM_CONTEXT_SCHEMA.tap do |schema|
  schema.query_resolver = QueryType
  schema.mutation_resolver = MutationType
end
