# coding: utf-8
require "../../spec_helper"

describe GraphQL::Schema, "using variables" do
  # When used in conjunction with Kemal as web framework, query variables
  # exposed by Kemal are of type Hash(String, JSON::Any). These should be able
  # to be parsed correctly.
  it "accepts query variables as Hash(String, JSON::Any)" do
    context = CustomContext.new({authenticated: true, name: "Anon"}, CUSTOM_CONTEXT_SCHEMA, nil)

    mutation = %{
      mutation addLog($input: LogInput!) {
        log(log: $input) {
          time
        }
      }
    }
    json_any = JSON.parse({time:     "now",
                           hostName: "docker host",
                           process:  {
                             name: "crystal spec",
                             pid:  42,
                           },
                           message: "in a bottle"}.to_json)
    variables = {"input" => json_any}
    variables.class.should eq Hash(String, JSON::Any)

    CUSTOM_CONTEXT_SCHEMA.execute(mutation, params: variables, context: context).should eq(
      {"data" => {"log" => {"time" => "now"}}}
    )
  end
end
