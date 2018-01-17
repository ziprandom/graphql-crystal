# coding: utf-8
require "../../spec_helper"

describe GraphQL::Schema do
  File.open(LogStore::TEMPFILENAME, "w").truncate

  describe "user unauthenticated (via context)" do
    context = CustomContext.new({authenticated: false, name: "Anon"}, CUSTOM_CONTEXT_SCHEMA, nil)

    describe "query" do
      it "disallows viewing the logs" do
        expected = {
          "data" => {
            "logs" => nil,
          },
          "errors" => [
            {
              "message" => "you are not allowed to read the logs Anon!",
              "path"    => ["logs"],
            },
          ],
        }
        CUSTOM_CONTEXT_SCHEMA.execute(
          "{ logs { time, hostName, userName, message, process { name pid } } }",
          nil,
          context
        ).should eq expected
      end
    end

    describe "mutation" do
      expected = {
        "data" => {
          "log" => nil,
        },
        "errors" => [
          {
            "message" => "you are not allowed to read the logs Anon!",
            "path"    => ["log"],
          },
        ],
      }

      mutation_string = %{
        mutation log($payload: LogInput) {
          log(log: $payload) {
            time
            hostName
            userName
            message
            process {
              name
              pid
            }
          }
        }
      }

      mutation_args = {
        "payload" => {
          "time"     => "Sep 4 22:57:21",
          "hostName" => "localhost",
          "message"  => "something occured that need to be logged",
          "process"  => {
            "name" => "crystal_graphql_server",
            "pid"  => 1,
          },
        },
      }

      CUSTOM_CONTEXT_SCHEMA.execute(mutation_string, mutation_args, context).should eq expected
    end
  end

  describe "user authenticated (via context)" do
    context = CustomContext.new({authenticated: true, name: "Alice"}, CUSTOM_CONTEXT_SCHEMA, nil)
    describe "query" do
      describe "logs query" do
        it "starts with an empty array of logs" do
          expected = {
            "data" => {
              "logs" => [] of JSON::Any,
            },
          }
          CUSTOM_CONTEXT_SCHEMA.execute(
            "{ logs { time, hostName, userName, message, process { name pid } } }",
            nil,
            context
          ).should eq expected
        end
      end
    end

    describe "mutation" do
      it "lets a log be pushed" do
        mutation_string = %{
          mutation log($payload: LogInput) {
            log(log: $payload) {
              time
              hostName
              userName
              message
              process {
                name
                pid
              }
            }
          }
        }

        mutation_args = {
          "payload" => {
            "time"     => "Sep 4 22:57:21",
            "hostName" => "localhost",
            "message"  => "something occured that need to be logged",
            "process"  => {
              "name" => "crystal_graphql_server",
              "pid"  => 1,
            },
          },
        }

        expected = {
          "data" => {
            "log" => {
              "time"     => "Sep 4 22:57:21",
              "hostName" => "localhost",
              "userName" => "Alice",
              "message"  => "something occured that need to be logged",
              "process"  => {
                "name" => "crystal_graphql_server",
                "pid"  => 1,
              },
            },
          },
        }

        CUSTOM_CONTEXT_SCHEMA.execute(mutation_string, mutation_args, context).should eq expected
      end

      it "persists the created log so later queries show it" do
        expected = {
          "data" => {
            "logs" => [{
              "time"     => "Sep 4 22:57:21",
              "hostName" => "localhost",
              "userName" => "Alice",
              "message"  => "something occured that need to be logged",
              "process"  => {
                "name" => "crystal_graphql_server",
                "pid"  => 1,
              },
            }],
          },
        }
        CUSTOM_CONTEXT_SCHEMA.execute(
          "{ logs { time, hostName, userName, message, process { name pid } } }",
          nil,
          context
        ).should eq expected
      end
    end
  end
end
