# coding: utf-8
# frozen_string_literal: true
require "../../spec_helper"

describe GraphQL::Language::Lexer do
  subject = GraphQL::Language::Lexer

  describe ".lex" do
    it "makes utf-8 comments" do
      comment_token = subject.lex("# 不要!\n{")
      comment_token.value.should eq "不要!"
    end

    it "unescapes escaped characters" do
      subject.lex(
        %{"\\" \\\\ \\/ \\b \\f \\n \\r \\t"}
      ).value.should eq "\" \\ / \b \f \n \r \t"
    end

    it "unescapes escaped unicode characters" do
      subject.lex(%{"\u0009"}).value.should eq "\t"
    end

    it "rejects bad unicode, even when there's good unicode in the string" do
      subject.lex(%{"\\u0XXF \\u0009"})
      true.should eq false
    rescue
      true.should eq true
    end
  end
end
