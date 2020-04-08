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

  def initialize(@name : String, @pid : Int32); end

  JSON.mapping({name: String, pid: Int32})
  field :name
  field :pid
end

class LogType
  include GraphQL::ObjectType

  def initialize(
    # ameba:disable Style/VariableNames
    @time : String, @hostName : String,
    # ameba:enable Style/VariableNames
    # ameba:disable Style/VariableNames
    @userName : String, @process : ProcessType,
    # ameba:enable Style/VariableNames
    @message : String
  ); end

  JSON.mapping(
    time: String,
    hostName: String,
    userName: String,
    process: ProcessType,
    message: String
  )

  field :time
  field :userName
  field :hostName
  field :process
  field :message
end

#
# Structs to hold input data
#
struct ProcessInput < GraphQL::Schema::InputType
  JSON.mapping(
    name: String,
    pid: Int32
  )

  def to_process_type
    ProcessType.new(@name, @pid)
  end
end

struct LogInput < GraphQL::Schema::InputType
  JSON.mapping(
    time: String,
    hostName: String,
    process: ProcessInput,
    message: String
  )

  def to_log_type(username)
    # ameba:disable Style/VariableNames
    LogType.new(@time, @hostName, username, @process.to_process_type, @message)
    # ameba:enable Style/VariableNames
  end
end

module LogStore
  extend self
  TEMPFILENAME = "./__logs.log"

  `touch #{TEMPFILENAME}`

  def read_logs
    raw_content = File.read(TEMPFILENAME)
    Array(LogType).from_json raw_content
  rescue
    [] of LogType
  end

  def write_logs(logs)
    File.write(TEMPFILENAME, logs.to_json)
  end
end

module QueryType
  include ::GraphQL::ObjectType
  extend self

  # ameba:disable Lint/UnusedArgument
  field :logs do |args, context|
    context = context.as(CustomContext)
    unless context.authenticated
      raise "you are not allowed to read the logs #{context.username}!"
    end
    LogStore.read_logs
  end
  # ameba:enable Lint/UnusedArgument
end

module MutationType
  include ::GraphQL::ObjectType
  extend self

  field :log do |args, context|
    context = context.as(CustomContext)

    unless context.authenticated
      raise "you are not allowed to read the logs #{context.username}!"
    end

    new_log = args["log"].as(LogInput).to_log_type(context.username)

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
  # add Types to parse from respective
  # Json Input Types
  schema.add_input_type("LogInput", LogInput)
  schema.add_input_type("ProcessInput", ProcessInput)
end
