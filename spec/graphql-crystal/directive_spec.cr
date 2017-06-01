# coding: utf-8
require "../spec_helper"

describe GraphQL::Directive do
  describe GraphQL::Directives::IncludeDirective do
    describe "on Field" do
      query_string = %{
        query userQuery($withName: Boolean!) {
          user(id: 0) {
            id
            ... on User @include(if: $withName) {
              name
            }
          }
        }
      }

      it "includes if :if argument is true" do
        TestSchema
          .execute(query_string, {"withName" => true})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0,
                           "name" => "otto neverthere"
                         }
                       }
                     })
      end
      it "excludes if :if argument is false" do
        TestSchema
          .execute(query_string, {"withName" => false})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0
                         }
                       }
                     })
      end
    end

    describe "on inline Fragment" do
      query_string = %{
        query userQuery($withName: Boolean!) {
          user(id: 0) {
            id
            ... on User @include(if: $withName) {
              name
            }
          }
        }
      }

      it "includes if :if argument is true" do
        TestSchema
          .execute(query_string, {"withName" => true})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0,
                           "name" => "otto neverthere"
                         }
                       }
                     })
      end

      it "excludes if :if argument is false" do
        TestSchema
          .execute(query_string, {"withName" => false})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0
                         }
                       }
                     })
      end
    end

    describe "on Fragment" do
      query_string = %{
        query userQuery($withName: Boolean!) {
          user(id: 0) {
            id
            ... userName @include(if: $withName)
          }
        }
        fragment userName on User {
          name
        }
      }

      it "includes if :if argument is true" do
        TestSchema
          .execute(query_string, {"withName" => true})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0,
                           "name" => "otto neverthere"
                         }
                       }
                     })
      end

      it "excludes if :if argument is false" do
        TestSchema
          .execute(query_string, {"withName" => false})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0
                         }
                       }
                     })
      end
    end
  end

  describe GraphQL::Directives::SkipDirective do
    describe "on Field" do
      query_string = %{
        query userQuery($skipName: Boolean!) {
          user(id: 0) {
            id
            ... on User @skip(if: $skipName) {
              name
            }
          }
        }
      }

      it "skips if :if argument is true" do
        TestSchema
          .execute(query_string, {"skipName" => true})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0
                         }
                       }
                     })
      end
      it "includes if :if argument is false" do
        TestSchema
          .execute(query_string, {"skipName" => false})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0,
                           "name" => "otto neverthere"
                         }
                       }
                     })
      end
    end

    describe "on inline Fragment" do
      query_string = %{
        query userQuery($skipName: Boolean!) {
          user(id: 0) {
            id
            ... on User @skip(if: $skipName) {
              name
            }
          }
        }
      }

      it "skips if :if argument is true" do
        TestSchema
          .execute(query_string, {"skipName" => true})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0
                         }
                       }
                     })
      end

      it "includes if :if argument is false" do
        TestSchema
          .execute(query_string, {"skipName" => false})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0,
                           "name" => "otto neverthere"
                         }
                       }
                     })
      end
    end

    describe "on Fragment" do
      query_string = %{
        query userQuery($skipName: Boolean!) {
          user(id: 0) {
            id
            ... userName @skip(if: $skipName)
          }
        }
        fragment userName on User {
          name
        }
      }

      it "skips if :if argument is true" do
        TestSchema
          .execute(query_string, {"skipName" => true})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0
                         }
                       }
                     })
      end

      it "includes if :if argument is false" do
        TestSchema
          .execute(query_string, {"skipName" => false})
          .should eq({
                       "data" => {
                         "user" => {
                           "id" => 0,
                           "name" => "otto neverthere"
                         }
                       }
                     })
      end
    end
  end
end
